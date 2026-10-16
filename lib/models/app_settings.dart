/// Persisted user settings for NetTorrent.
library;

/// Theme choices offered in Settings.
enum AppThemeMode { system, dark, light }

class AppSettings {
  /// null = platform default download folder (chosen at runtime).
  final String? downloadDir;
  final int maxSimultaneous;
  /// Bytes/sec, 0 = unlimited.
  final int maxDownloadSpeed;
  /// Bytes/sec, 0 = unlimited.
  final int maxUploadSpeed;
  final AppThemeMode themeMode;
  final bool notificationsEnabled;
  final bool launchOnStartup;
  /// Keep seeding completed torrents (upload to peers).
  final bool seedAfterComplete;
  final double seedRatioLimit;
  final int maxPeerConnections;
  final bool autoRetry;
  final int maxRetryAttempts;
  final bool confirmBeforeDelete;

  const AppSettings({
    this.downloadDir,
    this.maxSimultaneous = 3,
    this.maxDownloadSpeed = 0,
    this.maxUploadSpeed = 0,
    this.themeMode = AppThemeMode.dark,
    this.notificationsEnabled = true,
    this.launchOnStartup = false,
    this.seedAfterComplete = true,
    this.seedRatioLimit = 1.5,
    this.maxPeerConnections = 60,
    this.autoRetry = true,
    this.maxRetryAttempts = 3,
    this.confirmBeforeDelete = true,
  });

  AppSettings copyWith({
    String? downloadDir,
    bool clearDownloadDir = false,
    int? maxSimultaneous,
    int? maxDownloadSpeed,
    int? maxUploadSpeed,
    AppThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? launchOnStartup,
    bool? seedAfterComplete,
    double? seedRatioLimit,
    int? maxPeerConnections,
    bool? autoRetry,
    int? maxRetryAttempts,
    bool? confirmBeforeDelete,
  }) {
    return AppSettings(
      downloadDir:
          clearDownloadDir ? null : (downloadDir ?? this.downloadDir),
      maxSimultaneous: maxSimultaneous ?? this.maxSimultaneous,
      maxDownloadSpeed: maxDownloadSpeed ?? this.maxDownloadSpeed,
      maxUploadSpeed: maxUploadSpeed ?? this.maxUploadSpeed,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      launchOnStartup: launchOnStartup ?? this.launchOnStartup,
      seedAfterComplete: seedAfterComplete ?? this.seedAfterComplete,
      seedRatioLimit: seedRatioLimit ?? this.seedRatioLimit,
      maxPeerConnections: maxPeerConnections ?? this.maxPeerConnections,
      autoRetry: autoRetry ?? this.autoRetry,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      confirmBeforeDelete:
          confirmBeforeDelete ?? this.confirmBeforeDelete,
    );
  }

  Map<String, dynamic> toJson() => {
        'downloadDir': downloadDir,
        'maxSimultaneous': maxSimultaneous,
        'maxDownloadSpeed': maxDownloadSpeed,
        'maxUploadSpeed': maxUploadSpeed,
        'themeMode': themeMode.name,
        'notificationsEnabled': notificationsEnabled,
        'launchOnStartup': launchOnStartup,
        'seedAfterComplete': seedAfterComplete,
        'seedRatioLimit': seedRatioLimit,
        'maxPeerConnections': maxPeerConnections,
        'autoRetry': autoRetry,
        'maxRetryAttempts': maxRetryAttempts,
        'confirmBeforeDelete': confirmBeforeDelete,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      downloadDir: json['downloadDir'] as String?,
      maxSimultaneous: (json['maxSimultaneous'] as num?)?.toInt() ?? 3,
      maxDownloadSpeed: (json['maxDownloadSpeed'] as num?)?.toInt() ?? 0,
      maxUploadSpeed: (json['maxUploadSpeed'] as num?)?.toInt() ?? 0,
      themeMode: AppThemeMode.values.byName(
        json['themeMode'] as String? ?? AppThemeMode.dark.name,
      ),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      launchOnStartup: json['launchOnStartup'] as bool? ?? false,
      seedAfterComplete: json['seedAfterComplete'] as bool? ?? true,
      seedRatioLimit: (json['seedRatioLimit'] as num?)?.toDouble() ?? 1.5,
      maxPeerConnections: (json['maxPeerConnections'] as num?)?.toInt() ?? 60,
      autoRetry: json['autoRetry'] as bool? ?? true,
      maxRetryAttempts: (json['maxRetryAttempts'] as num?)?.toInt() ?? 3,
      confirmBeforeDelete: json['confirmBeforeDelete'] as bool? ?? true,
    );
  }
}
