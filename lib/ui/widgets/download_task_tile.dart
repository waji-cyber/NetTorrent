import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/download_task.dart';
import '../../services/download_manager.dart';
import 'dialogs.dart';

/// Small coloured pill showing a task's lifecycle state.
class TaskStatusChip extends StatelessWidget {
  final TaskStatus status;

  const TaskStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Colours are theme roles, never hardcoded.
    final (Color bg, Color fg) = switch (status) {
      TaskStatus.downloading => (cs.primary, cs.onPrimary),
      TaskStatus.queued => (cs.secondaryContainer, cs.onSecondaryContainer),
      TaskStatus.paused => (cs.tertiaryContainer, cs.onTertiaryContainer),
      TaskStatus.completed => (cs.tertiary, cs.onTertiary),
      TaskStatus.seeding => (cs.primaryContainer, cs.onPrimaryContainer),
      TaskStatus.failed => (cs.error, cs.onError),
      TaskStatus.cancelled =>
        (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    final label = switch (status) {
      TaskStatus.downloading => 'Downloading',
      TaskStatus.queued => 'Queued',
      TaskStatus.paused => 'Paused',
      TaskStatus.completed => 'Completed',
      TaskStatus.seeding => 'Seeding',
      TaskStatus.failed => 'Failed',
      TaskStatus.cancelled => 'Cancelled',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Card representation of one [DownloadTask]: name, status, progress bar,
/// sizes, live speed / ETA, error text and the pause/resume/retry/cancel/
/// delete/priority controls.
///
/// All numbers come from the task snapshot emitted by [DownloadManager];
/// nothing here is simulated.
class DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const DownloadTaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(downloadManagerProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final progress = task.progress;
    final totalLabel = task.totalBytes > 0
        ? '${formatBytes(task.receivedBytes)} / ${formatBytes(task.totalBytes)}'
        : formatBytes(task.receivedBytes);
    final percentLabel = progress == null
        ? 'size unknown'
        : '${(progress * 100).toStringAsFixed(0)}%';

    // Speed + ETA line, only meaningful while transferring.
    String? speedLine;
    if (task.status == TaskStatus.downloading) {
      final remaining =
          task.totalBytes > 0 ? task.totalBytes - task.receivedBytes : -1;
      final eta = formatEta(etaSeconds(
        remaining > 0 ? remaining : 0,
        task.speedBps,
      ),);
      final parts = <String>['↓ ${formatSpeed(task.speedBps)}', 'ETA $eta'];
      if (task.type == TaskType.torrent) {
        parts.add('↑ ${formatSpeed(task.uploadSpeedBps ?? 0)}');
      }
      speedLine = parts.join('  •  ');
    } else if (task.status == TaskStatus.seeding) {
      speedLine = '↑ ${formatSpeed(task.uploadSpeedBps ?? 0)} seeding';
    } else if (task.avgSpeedBps > 0 &&
        (task.status == TaskStatus.completed ||
            task.status == TaskStatus.cancelled)) {
      speedLine = 'avg ${formatSpeed(task.avgSpeedBps)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.type == TaskType.torrent
                      ? Icons.hub
                      : Icons.insert_drive_file,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TaskStatusChip(status: task.status),
              ],
            ),
            const SizedBox(height: 10),
            // Indeterminate while the total size is still unknown.
            if (progress == null)
              const LinearProgressIndicator()
            else
              LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalLabel, style: theme.textTheme.bodySmall),
                Text(
                  percentLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (speedLine != null) ...[
              const SizedBox(height: 4),
              Text(speedLine, style: theme.textTheme.bodySmall),
            ],
            // Torrent swarm details, when the engine exposes them.
            if (task.type == TaskType.torrent &&
                (task.peers != null || task.seeders != null)) ...[
              const SizedBox(height: 4),
              Text(
                'Peers ${task.peers ?? 0}  •  Seeders ${task.seeders ?? 0}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            if (task.status == TaskStatus.failed &&
                task.error != null) ...[
              const SizedBox(height: 4),
              Text(
                task.error!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Pause / resume depends on current state.
                if (task.status == TaskStatus.downloading ||
                    task.status == TaskStatus.queued)
                  IconButton(
                    tooltip: 'Pause',
                    icon: const Icon(Icons.pause),
                    onPressed: () => manager.pauseTask(task.id),
                  )
                else if (task.status == TaskStatus.paused)
                  IconButton(
                    tooltip: 'Resume',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => manager.resumeTask(task.id),
                  ),
                if (task.status == TaskStatus.failed)
                  IconButton(
                    tooltip: 'Retry',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => manager.retryTask(task.id),
                  ),
                if (task.isActive)
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: () => manager.cancelTask(task.id),
                  ),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.more_vert),
                  tooltip:
                      'Priority: ${TaskPriority.label(task.priority)}',
                  onSelected: (v) => manager.setPriority(task.id, v),
                  itemBuilder: (context) => [
                    for (final p in [
                      TaskPriority.low,
                      TaskPriority.normal,
                      TaskPriority.high,
                    ])
                      CheckedPopupMenuItem(
                        value: p,
                        checked: task.priority == p,
                        child: Text(TaskPriority.label(p)),
                      ),
                  ],
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _onDelete(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Delete flow: honours the "confirm before delete" setting and offers the
  /// "also delete downloaded files" checkbox when confirming.
  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsServiceProvider).settings;
    final manager = ref.read(downloadManagerProvider.notifier);
    if (!settings.confirmBeforeDelete) {
      await manager.removeTask(task.id);
      return;
    }
    final result = await confirmDeleteDialog(
      context,
      title: 'Delete download?',
      message: 'Remove "${task.name}" from the list?',
    );
    if (!result.confirmed) return;
    await manager.removeTask(task.id, deleteFiles: result.deleteFiles);
  }
}
