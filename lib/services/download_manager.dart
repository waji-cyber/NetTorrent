import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/app_settings.dart';
import '../models/download_task.dart';
import 'http_download_engine.dart';
import 'network_stats.dart';
import 'notifications_service.dart';
import 'settings_service.dart';
import 'torrent_service.dart';

/// Global providers. [settingsServiceProvider] is overridden in `main()` with
/// the real instance once SharedPreferences is ready.
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => throw UnimplementedError('settingsServiceProvider not overridden'),
);

final networkStatsProvider =
    StateNotifierProvider<NetworkStatsNotifier, NetworkStats>(
  (ref) => NetworkStatsNotifier(),
);

final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, List<DownloadTask>>(
  (ref) => DownloadManager(ref),
);

final navIndexProvider = StateProvider<int>((ref) => 0);
final searchQueryProvider = StateProvider<String>((ref) => '');
final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.all);

/// Central coordinator: owns the task list, the transfer queue, per-task
/// engines, statistics sampling and persistence.
///
/// UI never talks to engines directly; it calls these methods and watches
/// the emitted [List<DownloadTask>] snapshots.
class DownloadManager extends StateNotifier<List<DownloadTask>> {
  final Ref _ref;
  final _uuid = const Uuid();
  final _http = HttpDownloadEngine();
  final _torrents = TorrentService();
  final _notifications = NotificationsService();

  /// Active HTTP transfers keyed by task id.
  final Map<String, CancelToken> _httpTokens = {};

  /// Active torrent handles keyed by task id.
  final Map<String, ManagedTorrent> _torrentHandles = {};

  /// Bytes accounted for at the previous stats tick (for deltas).
  final Map<String, int> _lastTickBytes = {};

  Timer? _statsTimer;
  bool _initialised = false;

  DownloadManager(this._ref) : super(const []);

  AppSettings get _settings => _ref.read(settingsServiceProvider).settings;

  // ------------------------------------------------------------------ init

  /// Must be called once at startup: restores persisted tasks and starts the
  /// statistics sampler.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    await _notifications.init();
    await _restore();
    _statsTimer = Timer.periodic(kStatsTickInterval, (_) => _tickStats());
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    for (final token in _httpTokens.values) {
      token.cancel();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ add tasks

  /// Adds an HTTP(S) download. Throws [ArgumentError] for invalid URLs.
  Future<DownloadTask> addHttpDownload(
    String url, {
    String? fileName,
    String? saveDir,
    int priority = TaskPriority.normal,
  }) async {
    final clean = url.trim();
    if (!isValidDownloadUrl(clean)) {
      throw ArgumentError('Not a valid http/https download URL: $url');
    }
    final dir = saveDir ?? await defaultDownloadDir();
    final name = sanitizeFileName(
      fileName ?? fileNameFromUrl(clean),
    );
    final task = DownloadTask(
      id: _uuid.v4(),
      type: TaskType.http,
      name: name,
      source: clean,
      saveDir: dir,
      fileName: name,
      status: TaskStatus.queued,
      priority: priority,
      createdAt: DateTime.now(),
    );
    // Best-effort size probe so the UI can show totals immediately.
    try {
      final total = await _http.probeContentLength(clean).timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
      if (total != null) {
        _emit(task.copyWith(totalBytes: total));
      } else {
        _emit(task);
      }
    } catch (_) {
      _emit(task);
    }
    await _persist();
    _pumpQueue();
    return task;
  }

  /// Adds a torrent from a `.torrent` file. Validates metadata before
  /// queueing; throws [TorrentException] when the file is not a torrent.
  Future<DownloadTask> addTorrentFile(String torrentFilePath) async {
    final dir = await defaultDownloadDir();
    final id = _uuid.v4();
    final handle = await _torrents.addTorrentFile(
      id: id,
      torrentFilePath: torrentFilePath,
      saveDir: dir,
      onCompleted: () => _onTorrentFinished(id),
      onError: (m) => _onTaskError(id, m),
    );
    return _registerTorrent(id, handle, source: torrentFilePath, saveDir: dir);
  }

  /// Adds a torrent from a magnet link. Metadata is fetched first, which can
  /// take a while; the task appears as queued with a note in the meantime.
  Future<DownloadTask> addMagnet(String magnetUri) async {
    final clean = magnetUri.trim();
    if (!isValidMagnetUri(clean)) {
      throw ArgumentError('Not a valid magnet link.');
    }
    final dir = await defaultDownloadDir();
    final id = _uuid.v4();
    var task = DownloadTask(
      id: id,
      type: TaskType.torrent,
      name: 'Fetching metadata…',
      source: clean,
      saveDir: dir,
      status: TaskStatus.queued,
      createdAt: DateTime.now(),
    );
    _emit(task);
    try {
      final handle = await _torrents.addMagnet(
        id: id,
        magnetUri: clean,
        saveDir: dir,
        onCompleted: () => _onTorrentFinished(id),
        onError: (m) => _onTaskError(id, m),
      );
      task = await _registerTorrent(id, handle, source: clean, saveDir: dir);
    } catch (e) {
      _emit(task.copyWith(
        status: TaskStatus.failed,
        error: e.toString(),
      ),);
      await _persist();
    }
    return task;
  }

  Future<DownloadTask> _registerTorrent(
    String id,
    ManagedTorrent handle, {
    required String source,
    required String saveDir,
  }) async {
    _torrentHandles[id] = handle;
    final task = DownloadTask(
      id: id,
      type: TaskType.torrent,
      name: handle.name,
      source: source,
      saveDir: saveDir,
      status: TaskStatus.queued,
      totalBytes: handle.totalBytes,
      infoHash: handle.infoHash,
      createdAt: DateTime.now(),
    );
    handle.snapshots.listen((snap) {
      final current = _byId(id);
      if (current == null) return;
      _emit(current.copyWith(
        name: snap.name,
        receivedBytes: current.totalBytes > 0
            ? (snap.progress * current.totalBytes).round()
            : current.receivedBytes,
        speedBps: handle.currentDownloadSpeed,
        avgSpeedBps: snap.avgDownloadSpeedBps,
        peers: snap.connectedPeers,
        seeders: snap.totalPeersSeen,
        uploadSpeedBps: snap.uploadSpeedBps,
        totalBytes:
            current.totalBytes > 0 ? current.totalBytes : handle.totalBytes,
      ),);
    });
    _emit(task);
    await _persist();
    _pumpQueue();
    return task;
  }

  // -------------------------------------------------------- task controls

  void pauseTask(String id) {
    final task = _byId(id);
    if (task == null || !task.isActive) return;
    _httpTokens[id]?.cancel();
    _httpTokens.remove(id);
    _torrentHandles[id]?.pause();
    _emit(task.copyWith(status: TaskStatus.paused, speedBps: 0));
    _persist();
    _pumpQueue();
  }

  void resumeTask(String id) {
    final task = _byId(id);
    if (task == null) return;
    if (task.status != TaskStatus.paused &&
        task.status != TaskStatus.failed &&
        task.status != TaskStatus.cancelled) {
      return;
    }
    _emit(task.copyWith(status: TaskStatus.queued, clearError: true));
    _persist();
    _pumpQueue();
  }

  Future<void> cancelTask(String id) async {
    final task = _byId(id);
    if (task == null) return;
    await _stopEngines(id);
    // Remove the partial file so cancelled downloads do not litter the disk.
    await _deleteTaskFiles(task);
    _emit(task.copyWith(status: TaskStatus.cancelled, speedBps: 0));
    await _persist();
    _pumpQueue();
  }

  Future<void> retryTask(String id) async {
    final task = _byId(id);
    if (task == null) return;
    _emit(task.copyWith(
      status: TaskStatus.queued,
      clearError: true,
      retries: task.retries + 1,
    ),);
    await _persist();
    _pumpQueue();
  }

  /// Removes a task from the list. When [deleteFiles] is true the downloaded
  /// file(s) are deleted too — the UI must confirm this first.
  Future<void> removeTask(String id, {bool deleteFiles = false}) async {
    final task = _byId(id);
    if (task == null) return;
    await _stopEngines(id);
    if (deleteFiles) await _deleteTaskFiles(task);
    state = state.where((t) => t.id != id).toList();
    _lastTickBytes.remove(id);
    await _persist();
  }

  void setPriority(String id, int priority) {
    final task = _byId(id);
    if (task == null) return;
    _emit(task.copyWith(priority: priority.clamp(0, 2)));
    _persist();
    _pumpQueue();
  }

  Future<void> clearCompleted() async {
    final ids = state
        .where((t) =>
            t.status == TaskStatus.completed || t.status == TaskStatus.failed,)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      await _stopEngines(id);
    }
    state = state.where((t) => !ids.contains(t.id)).toList();
    await _persist();
  }

  /// Tasks matching [filter] and the current search query, newest first.
  List<DownloadTask> visibleTasks(TaskFilter filter, String query) {
    final q = query.trim().toLowerCase();
    final list = state.where((t) {
      final matchesFilter = switch (filter) {
        TaskFilter.all => true,
        TaskFilter.active => t.isActive,
        TaskFilter.completed =>
          t.status == TaskStatus.completed || t.status == TaskStatus.seeding,
      };
      final matchesQuery =
          q.isEmpty || t.name.toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<DownloadTask> get torrentTasks =>
      state.where((t) => t.type == TaskType.torrent).toList();

  // -------------------------------------------------------------- queue

  void _pumpQueue() {
    final maxSim = _settings.maxSimultaneous.clamp(1, 20);
    var active =
        state.where((t) => t.status == TaskStatus.downloading).length;
    final queued = state
        .where((t) => t.status == TaskStatus.queued)
        .toList()
      ..sort((a, b) {
        final p = b.priority.compareTo(a.priority);
        return p != 0 ? p : a.createdAt.compareTo(b.createdAt);
      });
    for (final task in queued) {
      if (active >= maxSim) break;
      active++;
      _startTask(task);
    }
  }

  void _startTask(DownloadTask task) {
    if (task.type == TaskType.http) {
      _startHttp(task);
    } else {
      _startTorrent(task);
    }
  }

  Future<void> _startHttp(DownloadTask task) async {
    final savePath = '${task.saveDir}/${task.fileName}';
    final token = CancelToken();
    _httpTokens[task.id] = token;
    _emit(task.copyWith(status: TaskStatus.downloading, clearError: true));

    // Resume from existing partial file when present.
    int startByte = 0;
    try {
      final existing = File(savePath);
      if (await existing.exists()) {
        startByte = await existing.length();
        if (task.totalBytes > 0 && startByte >= task.totalBytes) {
          _onHttpFinished(task.id);
          return;
        }
      }
    } catch (_) {}

    final startedAt = DateTime.now();
    try {
      await _http.download(
        url: task.source,
        savePath: savePath,
        startByte: startByte,
        maxBytesPerSecond: _settings.maxDownloadSpeed,
        cancelToken: token,
        onProgress: (p) {
          final current = _byId(task.id);
          if (current == null ||
              current.status != TaskStatus.downloading) {
            return;
          }
          _emit(current.copyWith(
            receivedBytes: p.receivedBytes,
            totalBytes: p.totalBytes > 0 ? p.totalBytes : current.totalBytes,
          ),);
        },
      );
      final current = _byId(task.id);
      if (current != null) {
        final elapsed =
            DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
        final avg = elapsed > 0 ? current.receivedBytes / elapsed : 0.0;
        _emit(current.copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
          speedBps: 0,
          avgSpeedBps: avg,
        ),);
      }
      _onHttpFinished(task.id);
    } on HttpDownloadException catch (e) {
      if (e.kind == HttpFailure.cancelled) return; // pause/cancel handled it
      _onTaskError(task.id,
          '${_friendlyHttpError(e)}${e.statusCode != null ? ' (HTTP ${e.statusCode})' : ''}',);
    } catch (e) {
      _onTaskError(task.id, 'Unexpected error: $e');
    } finally {
      _httpTokens.remove(task.id);
    }
  }

  void _startTorrent(DownloadTask task) {
    final existing = _torrentHandles[task.id];
    if (existing != null) {
      _emit(task.copyWith(status: TaskStatus.downloading, clearError: true));
      existing.resume();
      return;
    }
    // Torrent handle did not survive a restart: rebuild from the source.
    () async {
      try {
        final ManagedTorrent handle;
        if (task.source.toLowerCase().startsWith('magnet:')) {
          handle = await _torrents.addMagnet(
            id: task.id,
            magnetUri: task.source,
            saveDir: task.saveDir,
            onCompleted: () => _onTorrentFinished(task.id),
            onError: (m) => _onTaskError(task.id, m),
          );
        } else {
          handle = await _torrents.addTorrentFile(
            id: task.id,
            torrentFilePath: task.source,
            saveDir: task.saveDir,
            onCompleted: () => _onTorrentFinished(task.id),
            onError: (m) => _onTaskError(task.id, m),
          );
        }
        _torrentHandles[task.id] = handle;
        _emit(task.copyWith(status: TaskStatus.downloading, clearError: true));
        await handle.start();
      } catch (e) {
        _onTaskError(task.id, e.toString());
      }
    }();
  }

  void _onHttpFinished(String id) {
    _httpTokens.remove(id);
    final task = _byId(id);
    if (task == null) return;
    if (_settings.notificationsEnabled) {
      _notifications.show('Download complete', task.name);
    }
    _persist();
    _pumpQueue();
  }

  void _onTorrentFinished(String id) {
    final task = _byId(id);
    if (task == null) return;
    if (_settings.seedAfterComplete) {
      _emit(task.copyWith(
        status: TaskStatus.seeding,
        speedBps: 0,
        completedAt: DateTime.now(),
      ),);
      if (_settings.notificationsEnabled) {
        _notifications.show(
            'Torrent complete — seeding', '${task.name} is now seeding.',);
      }
    } else {
      _torrentHandles[id]?.stop();
      _torrentHandles.remove(id);
      _emit(task.copyWith(
        status: TaskStatus.completed,
        speedBps: 0,
        completedAt: DateTime.now(),
      ),);
      if (_settings.notificationsEnabled) {
        _notifications.show('Torrent complete', task.name);
      }
    }
    _persist();
    _pumpQueue();
  }

  void _onTaskError(String id, String message) {
    final task = _byId(id);
    if (task == null) return;
    _stopEngines(id);
    final settings = _settings;
    final shouldRetry = settings.autoRetry && task.retries < settings.maxRetryAttempts;
    if (shouldRetry) {
      final delay = Duration(
          seconds: kDefaultRetryDelaySeconds * (task.retries + 1),);
      _emit(task.copyWith(
        status: TaskStatus.queued,
        error: '$message — retrying in ${delay.inSeconds}s',
        retries: task.retries + 1,
        speedBps: 0,
      ),);
      Future.delayed(delay, () {
        if (_byId(id)?.status == TaskStatus.queued) _pumpQueue();
      });
    } else {
      _emit(task.copyWith(
        status: TaskStatus.failed,
        error: message,
        speedBps: 0,
      ),);
      if (settings.notificationsEnabled) {
        _notifications.show('Download failed', '${task.name}: $message');
      }
    }
    _persist();
    _pumpQueue();
  }

  String _friendlyHttpError(HttpDownloadException e) {
    return switch (e.kind) {
      HttpFailure.network =>
        'Network error. Check your connection and retry.',
      HttpFailure.httpError =>
        'The server refused the download${e.statusCode != null ? ' (HTTP ${e.statusCode})' : ''}.',
      HttpFailure.fileSystem =>
        'Could not write to disk. Check free space and folder permissions.',
      HttpFailure.cancelled => 'Cancelled.',
      HttpFailure.unknown => e.message,
    };
  }

  Future<void> _stopEngines(String id) async {
    _httpTokens[id]?.cancel();
    _httpTokens.remove(id);
    final handle = _torrentHandles.remove(id);
    if (handle != null) {
      try {
        await handle.stop();
      } catch (_) {}
    }
  }

  Future<void> _deleteTaskFiles(DownloadTask task) async {
    try {
      if (task.type == TaskType.http && task.fileName != null) {
        final f = File('${task.saveDir}/${task.fileName}');
        if (await f.exists()) await f.delete();
      } else if (task.type == TaskType.torrent) {
        // Only delete inside our own download dir, never outside it.
        final dir = Directory(task.saveDir);
        if (await dir.exists()) {
          final safeName = sanitizeFileName(task.name);
          final target = File('${task.saveDir}/$safeName');
          final targetDir = Directory('${task.saveDir}/$safeName');
          if (await target.exists()) await target.delete();
          if (await targetDir.exists()) await targetDir.delete(recursive: true);
        }
      }
    } catch (_) {
      // Best effort; the task is removed regardless.
    }
  }

  // ---------------------------------------------------------------- stats

  void _tickStats() {
    int downDelta = 0;
    int upDelta = 0;
    int peers = 0;
    for (final task in state) {
      final prev = _lastTickBytes[task.id] ?? task.receivedBytes;
      final delta = task.receivedBytes - prev;
      if (delta > 0) downDelta += delta;
      _lastTickBytes[task.id] = task.receivedBytes;
      if (task.peers != null) peers += task.peers!;
      // Instantaneous speed from the delta (torrent speeds come from engine).
      if (task.type == TaskType.http &&
          task.status == TaskStatus.downloading) {
        final speed = delta / kStatsTickInterval.inMilliseconds * 1000.0;
        final current = _byId(task.id);
        if (current != null && speed >= 0) {
          final elapsed = DateTime.now()
                  .difference(current.createdAt)
                  .inMilliseconds /
              1000.0;
          _emit(current.copyWith(
            speedBps: speed,
            avgSpeedBps:
                elapsed > 0 ? current.receivedBytes / elapsed : 0,
          ), persist: false,);
        }
      }
    }
    // Torrent upload contribution.
    for (final entry in _torrentHandles.entries) {
      // Approximated from the task snapshot updated by the sampler.
      final t = _byId(entry.key);
      if (t?.uploadSpeedBps != null) {
        upDelta +=
            (t!.uploadSpeedBps! * kStatsTickInterval.inMilliseconds / 1000)
                .round();
      }
    }
    _ref.read(networkStatsProvider.notifier).recordTick(
          downloadedBytesDelta: downDelta,
          uploadedBytesDelta: upDelta,
          connectedPeers: peers,
        );
  }

  // ----------------------------------------------------------- persistence

  Future<Directory> _appDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return getApplicationDocumentsDirectory();
    }
    return getApplicationSupportDirectory();
  }

  /// Platform-aware default download folder.
  Future<String> defaultDownloadDir() async {
    final custom = _settings.downloadDir;
    if (custom != null && custom.isNotEmpty) return custom;
    try {
      if (Platform.isAndroid) {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final dir = Directory('${ext.path}/$kDefaultDownloadSubdir');
          await dir.create(recursive: true);
          return dir.path;
        }
      } else {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dir =
              Directory('${downloads.path}/$kDefaultDownloadSubdir');
          await dir.create(recursive: true);
          return dir.path;
        }
      }
    } catch (_) {}
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$kDefaultDownloadSubdir');
    await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _persist() async {
    try {
      final dir = await _appDir();
      final file = File('${dir.path}/$kTasksFileName');
      final json =
          jsonEncode(state.map((t) => t.toJson()).toList());
      await file.writeAsString(json);
    } catch (_) {
      // Persistence is best-effort; the session keeps working in memory.
    }
  }

  Future<void> _restore() async {
    try {
      final dir = await _appDir();
      final file = File('${dir.path}/$kTasksFileName');
      if (!await file.exists()) return;
      final raw = await file.readAsString();
      final list = (jsonDecode(raw) as List)
          .map((e) => DownloadTask.fromJson(e as Map<String, dynamic>))
          .toList();
      // Anything mid-transfer at shutdown becomes paused; the user resumes.
      state = list
          .map((t) => t.isActive
              ? t.copyWith(status: TaskStatus.paused, speedBps: 0)
              : t,)
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  // ---------------------------------------------------------------- helpers

  DownloadTask? _byId(String id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _emit(DownloadTask updated, {bool persist = true}) {
    state = [
      for (final t in state) t.id == updated.id ? updated : t,
    ];
    if (persist) _persist();
  }
}
