import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications.
///
/// All calls are guarded: if the platform cannot show notifications the app
/// keeps working silently.
class NotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      // Note: flutter_local_notifications supports Android/iOS/macOS/Linux.
      // There is no Windows implementation, so on Windows show() becomes a
      // silent no-op (caught below) instead of crashing the app.
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'nettorrent_downloads',
        'Downloads',
        channelDescription: 'Download completion and failure alerts',
        importance: Importance.defaultImportance,
      );
      const details = NotificationDetails(android: androidDetails);
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
    } catch (_) {}
  }
}
