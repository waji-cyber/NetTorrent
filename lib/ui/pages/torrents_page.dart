import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_task.dart';
import '../../services/download_manager.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/empty_state.dart';

/// BitTorrent tasks. Each tile shows peers, seeders and upload speed
/// (rendered by [DownloadTaskTile] for torrent-type tasks).
class TorrentsPage extends ConsumerWidget {
  const TorrentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final torrents = tasks
        .where((t) => t.type == TaskType.torrent)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    void goToAdd() =>
        ref.read(navIndexProvider.notifier).state = 5;

    if (torrents.isEmpty) {
      return EmptyState(
        icon: Icons.hub,
        title: 'No torrents yet',
        subtitle: 'Add a .torrent file or a magnet link to start downloading.',
        action: Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.file_open),
              label: const Text('Add .torrent file'),
              onPressed: goToAdd,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Add magnet link'),
              onPressed: goToAdd,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${torrents.length} torrent${torrents.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Add .torrent file',
              icon: const Icon(Icons.file_open),
              onPressed: goToAdd,
            ),
            IconButton(
              tooltip: 'Add magnet link',
              icon: const Icon(Icons.link),
              onPressed: goToAdd,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...torrents.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DownloadTaskTile(task: t),
          ),
        ),
      ],
    );
  }
}
