import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Project information: what NetTorrent is, how it is built, and the
/// open-source licences of its key dependencies.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_download,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kAppName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $kAppVersion',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NetTorrent is a cross-platform download manager for '
                    'Windows and Android. It downloads files over HTTP/HTTPS '
                    'with pause/resume support and handles BitTorrent tasks '
                    '(.torrent files and magnet links) through a pure-Dart '
                    'engine — with queueing, bandwidth limits, a live network '
                    'monitor, and a localhost bridge for the browser extension.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            context,
            title: 'Technology stack',
            children: const [
              _StackRow(
                name: 'Flutter & Dart',
                detail: 'Cross-platform UI for Windows and Android',
              ),
              _StackRow(
                name: 'Riverpod (flutter_riverpod)',
                detail: 'Reactive state management',
              ),
              _StackRow(
                name: 'dio',
                detail: 'Streaming HTTP engine with Range resume',
              ),
              _StackRow(
                name: 'dtorrent_task_v2',
                detail:
                    'Pure-Dart BitTorrent engine: trackers, DHT, uTP/TCP',
              ),
              _StackRow(
                name: 'fl_chart',
                detail: 'Throughput graphs',
              ),
              _StackRow(
                name: 'shelf',
                detail: 'Localhost bridge server for the browser extension',
              ),
              _StackRow(
                name: 'shared_preferences',
                detail: 'Settings persistence',
              ),
              _StackRow(
                name: 'file_picker',
                detail: '.torrent files and folder selection',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionCard(
            context,
            title: 'Open-source licences',
            subtitle:
                'NetTorrent is built on these open-source packages. '
                'See each package page on pub.dev for the full licence text.',
            children: const [
              _LicenceRow(package: 'flutter_riverpod', licence: 'MIT'),
              _LicenceRow(package: 'dio', licence: 'MIT'),
              _LicenceRow(package: 'dtorrent_task_v2', licence: 'BSD-3-Clause'),
              _LicenceRow(package: 'fl_chart', licence: 'MIT'),
              _LicenceRow(package: 'shelf / shelf_router', licence: 'BSD-3-Clause'),
              _LicenceRow(package: 'shared_preferences', licence: 'BSD-3-Clause'),
              _LicenceRow(package: 'path_provider', licence: 'BSD-3-Clause'),
              _LicenceRow(package: 'file_picker', licence: 'MIT'),
              _LicenceRow(package: 'uuid', licence: 'MIT'),
              _LicenceRow(package: 'intl', licence: 'BSD-3-Clause'),
              _LicenceRow(
                package: 'flutter_local_notifications',
                licence: 'BSD-3-Clause',
              ),
              _LicenceRow(package: 'network_info_plus', licence: 'BSD-3-Clause'),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Project', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Computer Networks course project.\n'
                    'Team information goes here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StackRow extends StatelessWidget {
  final String name;
  final String detail;

  const _StackRow({required this.name, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chevron_right,
              size: 20, color: theme.colorScheme.primary,),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenceRow extends StatelessWidget {
  final String package;
  final String licence;

  const _LicenceRow({required this.package, required this.licence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(package, style: theme.textTheme.bodyMedium),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              licence,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
