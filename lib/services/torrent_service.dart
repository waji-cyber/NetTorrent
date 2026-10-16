import 'dart:async';
import 'dart:typed_data';

import 'package:b_encode_decode/b_encode_decode.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';

/// Why a torrent task failed.
enum TorrentFailure {
  invalidMetadata,
  metadataTimeout,
  engineError,
}

/// Typed failure for torrent operations.
class TorrentException implements Exception {
  final TorrentFailure kind;
  final String message;

  const TorrentException(this.kind, this.message);

  @override
  String toString() => 'TorrentException($kind): $message';
}

/// Live snapshot polled from the engine.
class TorrentSnapshot {
  /// 0.0 – 1.0
  final double progress;
  final int connectedPeers;
  final int totalPeersSeen;
  final double uploadSpeedBps;
  final double avgDownloadSpeedBps;
  final String name;

  const TorrentSnapshot({
    required this.progress,
    required this.connectedPeers,
    required this.totalPeersSeen,
    required this.uploadSpeedBps,
    required this.avgDownloadSpeedBps,
    required this.name,
  });
}

/// A single torrent managed by NetTorrent, wrapping a `TorrentTask` from
/// `dtorrent_task_v2` (pure-Dart engine: tracker + DHT + uTP/TCP).
///
/// All engine API usage here mirrors the package's documented surface:
/// `TorrentModel.parse`, `TorrentTask.newTask`, `start/pause/resume/stop`,
/// `createListener`, `MagnetParser.parse`, `MetadataDownloader.fromMagnet`.
class ManagedTorrent {
  final String id;
  final String? infoHash;
  final TorrentTask _task;
  final void Function()? onCompleted;
  final void Function(String message)? onError;

  Timer? _sampler;
  final _snapshotController = StreamController<TorrentSnapshot>.broadcast();
  DateTime _lastSampleAt = DateTime.now();
  int _lastDownloadedBytes = 0;
  double _currentDownSpeed = 0;

  ManagedTorrent({
    required this.id,
    required TorrentTask task,
    this.infoHash,
    this.onCompleted,
    this.onError,
  }) : _task = task;

  Stream<TorrentSnapshot> get snapshots => _snapshotController.stream;

  String get name {
    try {
      return _task.metaInfo.name;
    } catch (_) {
      return infoHash ?? id;
    }
  }

  /// Total size in bytes, -1 when the metadata does not expose it.
  int get totalBytes {
    try {
      final dynamic meta = _task.metaInfo;
      final dynamic length = meta.length;
      if (length is int) return length;
    } catch (_) {}
    return -1;
  }

  double get currentDownloadSpeed => _currentDownSpeed;

  Future<void> start() async {
    _attachListener();
    await _task.start();
    _startSampler();
  }

  void pause() {
    _task.pause();
    _sampler?.cancel();
  }

  void resume() {
    _task.resume();
    _startSampler();
  }

  Future<void> stop() async {
    _sampler?.cancel();
    await _task.stop();
    await _snapshotController.close();
  }

  void _attachListener() {
    final listener = _task.createListener();
    listener
      ..on<TaskCompleted>((_) => onCompleted?.call())
      ..on<AllComplete>((_) => onCompleted?.call())
      ..on<TaskStopped>((_) {});
  }

  void _startSampler() {
    _sampler?.cancel();
    _lastSampleAt = DateTime.now();
    _sampler = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        final progress = _task.progress.clamp(0.0, 1.0);
        final total = totalBytes;
        final downloaded =
            total > 0 ? (progress * total).round() : _lastDownloadedBytes;
        final now = DateTime.now();
        final dt = now.difference(_lastSampleAt).inMilliseconds / 1000.0;
        if (dt > 0 && total > 0) {
          _currentDownSpeed = (downloaded - _lastDownloadedBytes) / dt;
          if (_currentDownSpeed < 0) _currentDownSpeed = 0;
        }
        _lastDownloadedBytes = downloaded;
        _lastSampleAt = now;
        _snapshotController.add(
          TorrentSnapshot(
            progress: progress,
            connectedPeers: _task.connectedPeersNumber,
            totalPeersSeen: _task.allPeersNumber,
            uploadSpeedBps: _task.uploadSpeed,
            avgDownloadSpeedBps: _task.averageDownloadSpeed,
            name: name,
          ),
        );
      } catch (_) {
        // Engine shutting down; sampler stops with the task.
      }
    });
  }
}

/// Creates and validates torrent tasks. Metadata is validated *before* any
/// network activity starts: a .torrent must parse and a magnet must carry a
/// valid info hash.
class TorrentService {
  /// Adds a torrent from a `.torrent` file. The task is created paused —
  /// call [ManagedTorrent.start] to begin.
  Future<ManagedTorrent> addTorrentFile({
    required String id,
    required String torrentFilePath,
    required String saveDir,
    void Function()? onCompleted,
    void Function(String message)? onError,
  }) async {
    late final TorrentModel model;
    try {
      model = await TorrentModel.parse(torrentFilePath);
    } catch (e) {
      throw TorrentException(
        TorrentFailure.invalidMetadata,
        'Could not parse .torrent file: $e',
      );
    }
    String? infoHash;
    try {
      final dynamic meta = model;
      infoHash = meta.infoHashString as String?;
    } catch (_) {}
    final task = TorrentTask.newTask(model, saveDir);
    return ManagedTorrent(
      id: id,
      task: task,
      infoHash: infoHash,
      onCompleted: onCompleted,
      onError: onError,
    );
  }

  /// Adds a torrent from a magnet link. Metadata is fetched first over the
  /// network (BEP 9); throws [TorrentException] on timeout/failure.
  Future<ManagedTorrent> addMagnet({
    required String id,
    required String magnetUri,
    required String saveDir,
    Duration metadataTimeout = const Duration(minutes: 5),
    void Function(double progress)? onMetadataProgress,
    void Function()? onCompleted,
    void Function(String message)? onError,
  }) async {
    final magnet = MagnetParser.parse(magnetUri);
    if (magnet == null) {
      throw const TorrentException(
        TorrentFailure.invalidMetadata,
        'Invalid magnet link: missing or malformed info hash.',
      );
    }

    final downloader = MetadataDownloader.fromMagnet(magnetUri);
    final completer = Completer<Uint8List>();
    final listener = downloader.createListener();
    listener
      ..on<MetaDataDownloadComplete>((event) {
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(event.data));
        }
      })
      ..on<MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) {
          completer.completeError(
            TorrentException(
              TorrentFailure.metadataTimeout,
              'Failed to fetch torrent metadata: ${event.error}',
            ),
          );
        }
      })
      ..on<MetaDataDownloadProgress>((event) {
        onMetadataProgress?.call((event.progress).toDouble() / 100.0);
      });

    await downloader.startDownload();
    late final Uint8List metadataBytes;
    try {
      metadataBytes =
          await completer.future.timeout(metadataTimeout, onTimeout: () {
        throw const TorrentException(
          TorrentFailure.metadataTimeout,
          'Timed out fetching metadata. No peers responded — the info hash '
          'may be dead or unreachable from this network.',
        );
      },);
    } finally {
      try {
        await downloader.stop();
      } catch (_) {}
    }

    // The fetched bytes are the bencoded *info* dictionary. Re-wrap them
    // into a minimal torrent map the parser accepts.
    late final TorrentModel model;
    try {
      final dynamic infoDict = decode(metadataBytes);
      final map = <String, dynamic>{
        'info': infoDict,
        if (magnet.trackers.isNotEmpty)
          'announce': magnet.trackers.first.toString(),
      };
      model = TorrentParser.parseFromMap(map);
    } catch (e) {
      throw TorrentException(
        TorrentFailure.invalidMetadata,
        'Downloaded metadata was corrupt: $e',
      );
    }

    final task = TorrentTask.newTask(model, saveDir);
    return ManagedTorrent(
      id: id,
      task: task,
      infoHash: magnet.infoHashString,
      onCompleted: onCompleted,
      onError: onError,
    );
  }
}
