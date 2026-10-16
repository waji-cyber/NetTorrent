import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../services/download_manager.dart';
import 'pages/about_page.dart';
import 'pages/active_downloads_page.dart';
import 'pages/add_download_page.dart';
import 'pages/all_downloads_page.dart';
import 'pages/completed_downloads_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/network_monitor_page.dart';
import 'pages/settings_page.dart';
import 'pages/torrents_page.dart';

/// Root navigation shell.
///
/// Wide screens (>= 900 logical px) get an extended [NavigationRail];
/// narrow screens get an [AppBar] + [Drawer]. The selected destination is
/// stored in [navIndexProvider] so any page can navigate programmatically
/// (e.g. "add torrent" buttons jumping to the Add page).
class NetTorrentShell extends ConsumerWidget {
  const NetTorrentShell({super.key});

  static const List<String> _titles = [
    'Dashboard',
    'All Downloads',
    'Active Downloads',
    'Completed Downloads',
    'Torrents',
    'Add Download',
    'Network Monitor',
    'Settings',
    'About',
  ];

  static const List<IconData> _icons = [
    Icons.dashboard,
    Icons.download,
    Icons.play_arrow,
    Icons.check_circle,
    Icons.hub,
    Icons.add_circle,
    Icons.network_check,
    Icons.settings,
    Icons.info,
  ];

  static const List<Widget> _pages = [
    DashboardPage(),
    AllDownloadsPage(),
    ActiveDownloadsPage(),
    CompletedDownloadsPage(),
    TorrentsPage(),
    AddDownloadPage(),
    NetworkMonitorPage(),
    SettingsPage(),
    AboutPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    void go(int i) {
      ref.read(navIndexProvider.notifier).state = i;
      // Close the drawer on narrow screens after navigating.
      if (!wide) Navigator.of(context).pop();
    }

    final body = Scaffold(
      appBar: AppBar(title: Text(_titles[index])),
      body: _pages[index],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: true,
              selectedIndex: index,
              onDestinationSelected: (i) =>
                  ref.read(navIndexProvider.notifier).state = i,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_download,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      kAppName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    label: Text(_titles[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titles[index])),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.cloud_download,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kAppName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Download manager',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _titles.length; i++)
              ListTile(
                leading: Icon(_icons[i]),
                title: Text(_titles[i]),
                selected: i == index,
                onTap: () => go(i),
              ),
          ],
        ),
      ),
      body: _pages[index],
    );
  }
}
