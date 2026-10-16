import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/app_settings.dart';

/// Loads, caches and persists [AppSettings].
///
/// Exposes a broadcast [stream] so UI can react to changes made anywhere
/// (settings page, quick toggles, platform handlers).
class SettingsService {
  final SharedPreferences _prefs;
  final _controller = StreamController<AppSettings>.broadcast();
  late AppSettings _settings;

  SettingsService._(this._prefs) {
    _settings = _read();
  }

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  AppSettings get settings => _settings;
  Stream<AppSettings> get stream => _controller.stream;

  AppSettings _read() {
    final raw = _prefs.getString(kSettingsPrefsKey);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupt prefs: fall back to defaults rather than crashing.
      return const AppSettings();
    }
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    await _prefs.setString(kSettingsPrefsKey, jsonEncode(next.toJson()));
    _controller.add(next);
  }

  Future<void> reset() => update(const AppSettings());

  void dispose() => _controller.close();
}
