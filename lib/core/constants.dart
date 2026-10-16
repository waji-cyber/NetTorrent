/// Application-wide constants for NetTorrent.
library;

/// Display name of the application.
const String kAppName = 'NetTorrent';

/// Current application version (keep in sync with pubspec.yaml).
const String kAppVersion = '0.1.0';

/// Port used by the localhost bridge server that the browser extension talks to.
const int kBridgePort = 17846;

/// Storage key / file names.
const String kTasksFileName = 'nettorrent_tasks.json';
const String kSettingsPrefsKey = 'nettorrent_settings_v1';
const String kBridgeTokenPrefsKey = 'nettorrent_bridge_token_v1';

/// Network / queue defaults.
const int kDefaultMaxSimultaneous = 3;
const int kDefaultMaxPeers = 60;
const int kDefaultRetryAttempts = 3;
const int kDefaultRetryDelaySeconds = 10;

/// HTTP client timeouts.
const Duration kHttpConnectTimeout = Duration(seconds: 15);
const Duration kHttpReceiveTimeout = Duration(seconds: 30);

/// How often per-task speed samplers tick.
const Duration kStatsTickInterval = Duration(seconds: 1);

/// Number of speed samples kept for the throughput graph (120 = 2 minutes).
const int kSpeedHistoryCapacity = 120;

/// Subdirectory created inside the user's download folder.
const String kDefaultDownloadSubdir = 'NetTorrent';
