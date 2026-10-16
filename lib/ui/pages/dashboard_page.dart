import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils.dart';
import '../../models/download_task.dart';
import '../../services/download_manager.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/speed_graph.dart';
import '../widgets/stat_card.dart';

/// Overview page: headline stats, live throughput graph and recent tasks.
///
/// Every number is read from providers — nothing is simulated.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final stats = ref.watch(networkStatsProvider);

    final activeCount = tasks.where((t) => t.isActive).length;
    final completedCount = tasks
        .where((t) =>
            t.status == TaskStatus.completed ||
            t.status == TaskStatus.seeding,)
        .length;
    final recent = tasks.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentFive = recent.take(5).toList();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  StatCard(
                    title: 'Active',
                    value: '$activeCount',
                    icon: Icons.play_arrow,
                    subtitle: 'downloading or queued',
                  ),
                  StatCard(
                    title: 'Completed',
                    value: '$completedCount',
                    icon: Icons.check_circle,
                    subtitle: 'finished tasks',
                  ),
                  StatCard(
                    title: 'Download',
                    value: formatSpeed(stats.downloadBps),
                    icon: Icons.arrow_downward,
                    subtitle: 'current speed',
                  ),
                  StatCard(
                    title: 'Upload',
                    value: formatSpeed(stats.uploadBps),
                    icon: Icons.arrow_upward,
                    subtitle: 'current speed',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Throughput', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SpeedGraph(samples: stats.history),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _legendDot(cs.primary, 'Download'),
                      const SizedBox(width: 16),
                      _legendDot(cs.tertiary, 'Upload'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Recent downloads', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          if (recentFive.isEmpty)
            const EmptyState(
              icon: Icons.download,
              title: 'No downloads yet',
              subtitle: 'Add your first download to see it here.',
            )
          else
            ...recentFive.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DownloadTaskTile(task: t),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
