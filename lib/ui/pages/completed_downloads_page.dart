import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_task.dart';
import '../../services/download_manager.dart';
import '../widgets/dialogs.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/empty_state.dart';

/// Finished tasks, with a "Clear completed" action.
class CompletedDownloadsPage extends ConsumerWidget {
  const CompletedDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(downloadManagerProvider);
    final visible = ref
        .read(downloadManagerProvider.notifier)
        .visibleTasks(TaskFilter.completed, '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Completed downloads',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear completed'),
                onPressed: visible.isEmpty
                    ? null
                    : () => _clearCompleted(context, ref),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(
                  icon: Icons.check_circle,
                  title: 'Nothing completed yet',
                  subtitle:
                      'Finished downloads will be listed here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: visible.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DownloadTaskTile(task: visible[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _clearCompleted(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Clear completed?',
      message:
          'Remove all completed and failed entries from the list? '
          'Downloaded files stay on disk.',
      confirmLabel: 'Clear',
    );
    if (!ok) return;
    await ref.read(downloadManagerProvider.notifier).clearCompleted();
  }
}
