import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_providers.dart';
import 'core/theme.dart';
import 'models/app_settings.dart';
import 'services/bridge_server.dart';
import 'services/download_manager.dart';
import 'services/settings_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = await SettingsService.create();

  runApp(
    ProviderScope(
      overrides: [
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const NetTorrentApp(),
    ),
  );
}

/// Post-frame bootstrap: restore tasks, start the localhost bridge.
class _Bootstrap extends StatefulWidget {
  final Widget child;
  const _Bootstrap({required this.child});

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final container = ProviderScope.containerOf(context);
      await container
          .read(downloadManagerProvider.notifier)
          .init();
      await container.read(bridgeServerProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Root widget wiring theme + bootstrap.
class NetTorrentApp extends ConsumerWidget {
  const NetTorrentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider);
    // Keep the theme provider in sync when settings change elsewhere.
    ref.listen(settingsServiceProvider, (_, service) {
      ref.read(appThemeModeProvider.notifier).state =
          switch (service.settings.themeMode) {
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
      };
    });
    return _Bootstrap(
      child: MaterialApp(
        title: 'NetTorrent',
        debugShowCheckedModeBanner: false,
        theme: NetTorrentTheme.light(),
        darkTheme: NetTorrentTheme.dark(),
        themeMode: themeMode,
        home: const NetTorrentShell(),
      ),
    );
  }
}
