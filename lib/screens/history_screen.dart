import 'dart:io';

import 'package:flutter/material.dart';

import '../state.dart';
import '../widgets.dart';

class HistoryScreen extends StatelessWidget {
  /// Called after an entry is loaded so the shell can jump to the Search tab.
  final VoidCallback onOpened;
  const HistoryScreen({super.key, required this.onOpened});

  Future<void> _confirmClear(BuildContext context, HistoryController h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All saved searches and their images will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await h.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final h = scope.history;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            centerTitle: false,
            actions: [
              if (h.entries.isNotEmpty)
                IconButton(
                  tooltip: 'Clear all',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context, h),
                ),
            ],
          ),
          body: h.entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 56, color: cs.outline),
                      const SizedBox(height: 12),
                      const Text('No searches yet'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: h.entries.length,
                  itemBuilder: (context, i) {
                    final e = h.entries[i];
                    return Dismissible(
                      key: ValueKey(e.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
                      ),
                      onDismissed: (_) => h.remove(e.id),
                      child: Card(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        margin: const EdgeInsets.only(bottom: 10),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(e.imagePath),
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              cacheWidth: 200,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Icon(Icons.broken_image_outlined)),
                            ),
                          ),
                          title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${timeAgo(e.createdAt)} • ${e.totalMatches} results'),
                          onTap: () {
                            scope.lens.loadFromHistory(e);
                            onOpened();
                          },
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
