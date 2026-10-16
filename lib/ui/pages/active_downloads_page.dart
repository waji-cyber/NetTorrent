import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_task.dart';
import '../../services/download_manager.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/empty_state.dart';

/// Tasks that are currently downloading or queued, with search.
class ActiveDownloadsPage extends ConsumerStatefulWidget {
  const ActiveDownloadsPage({super.key});

  @override
  ConsumerState<ActiveDownloadsPage> createState() =>
      _ActiveDownloadsPageState();
}

class _ActiveDownloadsPageState extends ConsumerState<ActiveDownloadsPage> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    ref.watch(downloadManagerProvider);
    final visible = ref
        .read(downloadManagerProvider.notifier)
        .visibleTasks(TaskFilter.active, query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search active downloads',
              border: const OutlineInputBorder(),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    ),
            ),
            onChanged: (v) =>
                ref.read(searchQueryProvider.notifier).state = v,
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(
                  icon: Icons.play_arrow,
                  title: 'No active downloads',
                  subtitle:
                      'Downloads you start or resume will appear here.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
}
