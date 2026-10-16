/// Core domain model: a single download managed by NetTorrent.
///
/// Covers both direct HTTP(S) downloads and BitTorrent tasks. Instances are
/// immutable; use [copyWith] to produce updated snapshots. Persisted as JSON
/// so the task list survives application restarts.
library;

/// What kind of download this task represents.
enum TaskType {
  http,
  torrent,
}

/// Lifecycle state of a task.
enum TaskStatus {
  /// Waiting for a free download slot.
  queued,

  /// Actively transferring data.
  downloading,

  /// User-paused; resume continues from stored progress.
  paused,

  /// Finished successfully (HTTP) — for torrents see [seeding].
  completed,

  /// Stopped because of an error; see [DownloadTask.error].
  failed,

  /// User-cancelled before completion.
  cancelled,

  /// Torrent finished downloading and is now uploading to peers.
  seeding,
}

/// List filter used by the downloads pages.
enum TaskFilter { all, active, completed }

/// Priority levels for queue ordering.
class TaskPriority {
  static const int low = 0;
  static const int normal = 1;
  static const int high = 2;

  static String label(int value) {
    switch (value) {
      case low:
        return 'Low';
      case high:
        return 'High';
      default:
        return 'Normal';
    }
  }
}

class DownloadTask {
  final String id;
  final TaskType type;
  final String name;
  /// Original source: HTTP(S) URL, magnet URI, or .torrent file path.
  final String source;
  final String saveDir;
  final String? fileName;
  final TaskStatus status;
  /// Total bytes, or -1 when the server did not advertise a size.
  final int totalBytes;
  final int receivedBytes;
  /// Instantaneous throughput measured by the sampler.
  final double speedBps;
  /// Lifetime average throughput.
  final double avgSpeedBps;
  final int priority;
  final String? error;
  final int retries;
  final DateTime createdAt;
  final DateTime? completedAt;

  // --- BitTorrent specific (null for HTTP tasks) ---
  final String? infoHash;
  final int? peers;
  final int? seeders;
  final double? uploadSpeedBps;

  const DownloadTask({
    required this.id,
    required this.type,
    required this.name,
    required this.source,
    required this.saveDir,
    this.fileName,
    required this.status,
    this.totalBytes = -1,
    this.receivedBytes = 0,
    this.speedBps = 0,
    this.avgSpeedBps = 0,
    this.priority = TaskPriority.normal,
    this.error,
    this.retries = 0,
    required this.createdAt,
    this.completedAt,
    this.infoHash,
    this.peers,
    this.seeders,
    this.uploadSpeedBps,
  });

  /// 0.0 – 1.0, or null when the total size is unknown.
  double? get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  bool get isActive =>
      status == TaskStatus.downloading || status == TaskStatus.queued;

  bool get isFinished =>
      status == TaskStatus.completed ||
      status == TaskStatus.cancelled ||
      status == TaskStatus.failed;

  DownloadTask copyWith({
    String? name,
    String? saveDir,
    String? fileName,
    TaskStatus? status,
    int? totalBytes,
    int? receivedBytes,
    double? speedBps,
    double? avgSpeedBps,
    int? priority,
    String? error,
    bool clearError = false,
    int? retries,
    DateTime? completedAt,
    String? infoHash,
    int? peers,
    int? seeders,
    double? uploadSpeedBps,
  }) {
    return DownloadTask(
      id: id,
      type: type,
      name: name ?? this.name,
      source: source,
      saveDir: saveDir ?? this.saveDir,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      speedBps: speedBps ?? this.speedBps,
      avgSpeedBps: avgSpeedBps ?? this.avgSpeedBps,
      priority: priority ?? this.priority,
      error: clearError ? null : (error ?? this.error),
      retries: retries ?? this.retries,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      infoHash: infoHash ?? this.infoHash,
      peers: peers ?? this.peers,
      seeders: seeders ?? this.seeders,
      uploadSpeedBps: uploadSpeedBps ?? this.uploadSpeedBps,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'name': name,
        'source': source,
        'saveDir': saveDir,
        'fileName': fileName,
        'status': status.name,
        'totalBytes': totalBytes,
        'receivedBytes': receivedBytes,
        'avgSpeedBps': avgSpeedBps,
        'priority': priority,
        'error': error,
        'retries': retries,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'infoHash': infoHash,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      type: TaskType.values.byName(json['type'] as String),
      name: json['name'] as String,
      source: json['source'] as String,
      saveDir: json['saveDir'] as String,
      fileName: json['fileName'] as String?,
      status: TaskStatus.values.byName(json['status'] as String),
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? -1,
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      avgSpeedBps: (json['avgSpeedBps'] as num?)?.toDouble() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? TaskPriority.normal,
      error: json['error'] as String?,
      retries: (json['retries'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      infoHash: json['infoHash'] as String?,
    );
  }
}
