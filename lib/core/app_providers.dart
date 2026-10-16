import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/download_manager.dart';

/// Global theme mode, initialised from persisted settings.
///
/// Lives here (not in main.dart) so pages can import it without creating
/// an import cycle back to the application entrypoint.
final appThemeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.watch(settingsServiceProvider).settings;
  return switch (settings.themeMode) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
  };
});
