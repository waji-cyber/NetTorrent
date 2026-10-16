import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_task.dart';
import '../../services/download_manager.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/empty_state.dart';

/// Full task list with search and status filter chips.
class AllDownloadsPage extends ConsumerStatefulWidget {
  const AllDownloadsPage({super.key});

  @override
  ConsumerState<AllDownloadsPage> createState() => _AllDownloadsPageState();
}

class _AllDownloadsPageState extends ConsumerState<AllDownloadsPage> {
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
    final filter = ref.watch(taskFilterProvider);
    final query = ref.watch(searchQueryProvider);
    // Watch the raw list so the page rebuilds on every task update…
    ref.watch(downloadManagerProvider);
    // …then apply the shared filter/search logic from the manager.
    final visible = ref
        .read(downloadManagerProvider.notifier)
        .visibleTasks(filter, query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search downloads',
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final f in TaskFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(f)),
                    selected: filter == f,
                    onSelected: (_) =>
                        ref.read(taskFilterProvider.notifier).state = f,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(
                  icon: Icons.download,
                  title: 'No downloads found',
                  subtitle:
                      'Try a different search or filter, or add a new download.',
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

  String _filterLabel(TaskFilter f) => switch (f) {
        TaskFilter.all => 'All',
        TaskFilter.active => 'Active',
        TaskFilter.completed => 'Completed',
      };
}
