import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';

/// One throughput sample for the monitor graph.
class SpeedSample {
  final DateTime at;
  final double downBps;
  final double upBps;

  const SpeedSample(this.at, this.downBps, this.upBps);
}

/// Aggregate transfer statistics for the current session.
class NetworkStats {
  /// Instantaneous download throughput (exponential moving average).
  final double downloadBps;

  /// Instantaneous upload throughput (exponential moving average).
  final double uploadBps;

  final int totalDownloadedBytes;
  final int totalUploadedBytes;
  final int connectedPeers;
  final DateTime sessionStart;

  /// Ring buffer of recent samples for the throughput graph.
  final List<SpeedSample> history;

  const NetworkStats({
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.totalDownloadedBytes = 0,
    this.totalUploadedBytes = 0,
    this.connectedPeers = 0,
    required this.sessionStart,
    this.history = const [],
  });

  NetworkStats copyWith({
    double? downloadBps,
    double? uploadBps,
    int? totalDownloadedBytes,
    int? totalUploadedBytes,
    int? connectedPeers,
    List<SpeedSample>? history,
  }) {
    return NetworkStats(
      downloadBps: downloadBps ?? this.downloadBps,
      uploadBps: uploadBps ?? this.uploadBps,
      totalDownloadedBytes:
          totalDownloadedBytes ?? this.totalDownloadedBytes,
      totalUploadedBytes: totalUploadedBytes ?? this.totalUploadedBytes,
      connectedPeers: connectedPeers ?? this.connectedPeers,
      sessionStart: sessionStart,
      history: history ?? this.history,
    );
  }
}

/// Collects per-tick byte counters from the download manager and maintains
/// smoothed speeds plus a bounded history for graphs.
class NetworkStatsNotifier extends StateNotifier<NetworkStats> {
  NetworkStatsNotifier() : super(NetworkStats(sessionStart: DateTime.now()));

  static const double _alpha = 0.35; // EMA smoothing factor

  /// Feed raw byte deltas observed since the previous tick.
  void recordTick({
    required int downloadedBytesDelta,
    required int uploadedBytesDelta,
    required int connectedPeers,
    Duration tick = kStatsTickInterval,
  }) {
    final seconds = tick.inMilliseconds / 1000.0;
    if (seconds <= 0) return;
    final instantDown = downloadedBytesDelta / seconds;
    final instantUp = uploadedBytesDelta / seconds;

    final prev = state;
    final smoothDown =
        prev.downloadBps + _alpha * (instantDown - prev.downloadBps);
    final smoothUp =
        prev.uploadBps + _alpha * (instantUp - prev.uploadBps);

    final history = List<SpeedSample>.of(prev.history)
      ..add(SpeedSample(DateTime.now(), smoothDown, smoothUp));
    while (history.length > kSpeedHistoryCapacity) {
      history.removeAt(0);
    }

    state = prev.copyWith(
      downloadBps: smoothDown < 0 ? 0 : smoothDown,
      uploadBps: smoothUp < 0 ? 0 : smoothUp,
      totalDownloadedBytes:
          prev.totalDownloadedBytes + downloadedBytesDelta,
      totalUploadedBytes: prev.totalUploadedBytes + uploadedBytesDelta,
      connectedPeers: connectedPeers,
      history: history,
    );
  }

  void reset() {
    state = NetworkStats(sessionStart: DateTime.now());
  }
}
