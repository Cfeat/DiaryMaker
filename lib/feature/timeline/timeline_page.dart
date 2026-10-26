import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/shell_action_gateway.dart';
import '../../core/entry/entry.dart';
import '../../core/sync/sync_meta.dart';
import '../../foundation/platform/layout_breakpoints.dart';
import '../../app/l10n/app_strings.dart';
import '../editor/editor_page.dart';
import '../settings/settings_hub_page.dart';

/// Diary timeline: date-desc summaries, empty state, desktop ↑↓ / mobile swipe.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({
    super.key,
    this.onOpenEntry,
    this.onComposeNew,
    this.listFocusNode,
    this.embedded = false,
  });

  /// Split layout: select entry without pushing a route.
  final ValueChanged<Entry?>? onOpenEntry;

  /// Split layout: parent composes a new entry in the detail pane.
  final VoidCallback? onComposeNew;

  /// Optional focus node for list keyboard navigation (desktop shortcuts).
  final FocusNode? listFocusNode;

  /// When true, hide FAB if parent provides actions.
  final bool embedded;

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  FocusNode? _ownedFocus;
  late final VoidCallback _newEntryHandler;
  late final ShellActionGateway _shellActions;
  int _selectedIndex = 0;

  FocusNode get _focusNode => widget.listFocusNode ?? _ownedFocus!;

  @override
  void initState() {
    super.initState();
    if (widget.listFocusNode == null) {
      _ownedFocus = FocusNode();
    }
    _newEntryHandler = _handleNewEntryShortcut;
    _shellActions = ref.read(shellActionGatewayProvider);
    _shellActions.registerNewEntry(_newEntryHandler);
  }

  @override
  void dispose() {
    _shellActions.unregisterNewEntry(_newEntryHandler);
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _handleNewEntryShortcut() {
    if (widget.onComposeNew != null) {
      widget.onComposeNew!();
    } else {
      _openEditor(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(appHostProvider);
    final useSplit = LayoutBreakpoints.useSplitLayout(context);
    final asyncEntries = ref.watch(timelineEntriesProvider);

    final conflicts = ref.watch(syncConflictsProvider);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text(S.timelineTitle),
              actions: [
                conflicts.when(
                  data: (list) => list.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          key: const Key('timeline_conflict_button'),
                          tooltip: S.timelineConflicts,
                          onPressed: () => _showConflicts(list),
                          icon: Badge(
                            label: Text('${list.length}'),
                            child: const Icon(Icons.warning_amber_outlined),
                          ),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                IconButton(
                  key: const Key('timeline_sync_settings'),
                  tooltip: S.timelineSyncSettings,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsHubPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_outlined),
                ),
              ],
            ),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton(
              key: const Key('timeline_new_entry'),
              tooltip: S.timelineNew,
              onPressed: () => _openEditor(null),
              child: const Icon(Icons.edit_note_rounded),
            ),
      body: asyncEntries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const _EmptyTimeline();
          }
          final list = Focus(
            focusNode: _focusNode,
            autofocus: useSplit || host.supportsDesktopShortcuts,
            onKeyEvent: (useSplit || host.supportsDesktopShortcuts)
                ? (node, event) => _onKey(event, entries)
                : null,
            child: ListView.builder(
              key: const Key('timeline_list'),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final tile = _EntrySummaryTile(
                  entry: entry,
                  selected: useSplit && index == _selectedIndex,
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    if (widget.onOpenEntry != null) {
                      widget.onOpenEntry!(entry);
                    } else {
                      _openEditor(entry);
                    }
                  },
                );
                // Swipe-to-delete on narrow (phone) layouts only.
                if (!useSplit && host.usesMobileShell) {
                  return Dismissible(
                    key: Key('dismiss_${entry.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _confirmDelete(entry),
                    background: Container(
                      color: Theme.of(context).colorScheme.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: tile,
                  );
                }
                return tile;
              },
            ),
          );
          return list;
        },
      ),
    );
  }

  KeyEventResult _onKey(KeyEvent event, List<Entry> entries) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, entries.length - 1);
      });
      widget.onOpenEntry?.call(entries[_selectedIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, entries.length - 1);
      });
      widget.onOpenEntry?.call(entries[_selectedIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final entry = entries[_selectedIndex];
      if (widget.onOpenEntry != null) {
        widget.onOpenEntry!(entry);
      } else {
        _openEditor(entry);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<bool> _confirmDelete(Entry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.deleteEntryTitle),
        content: Text(
          entry.title.isEmpty ? S.deleteEntryBody : entry.title,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(entryRepositoryProvider).delete(entry.id);
      await ref.read(timelineEntriesProvider.notifier).refresh();
      widget.onOpenEntry?.call(null);
      return true;
    }
    return false;
  }

  Future<void> _openEditor(Entry? entry) async {
    if (widget.onOpenEntry != null && entry != null) {
      widget.onOpenEntry!(entry);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EditorPage(entryId: entry?.id),
      ),
    );
    await ref.read(timelineEntriesProvider.notifier).refresh();
  }

  Future<void> _showConflicts(List<SyncMeta> list) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.syncConflictsTitle),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final meta in list)
                ListTile(
                  title: Text(meta.entryId),
                  subtitle: const Text(S.syncConflictSubtitle),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final creds = await ref
                              .read(syncCredentialsStoreProvider)
                              .read();
                          if (creds == null) return;
                          await ref.read(syncEngineProvider).resolveKeepLocal(
                                entryId: meta.entryId,
                                credentials: creds,
                              );
                          ref.invalidate(syncConflictsProvider);
                          await ref
                              .read(timelineEntriesProvider.notifier)
                              .refresh();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text(S.keepLocal),
                      ),
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(syncEngineProvider)
                              .resolveKeepRemote(entryId: meta.entryId);
                          ref.invalidate(syncConflictsProvider);
                          await ref
                              .read(timelineEntriesProvider.notifier)
                              .refresh();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text(S.keepRemote),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(S.close),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              S.timelineEmptyTitle,
              key: const Key('timeline_empty_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              S.timelineEmptyBody,
              key: Key('timeline_empty_body'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntrySummaryTile extends StatelessWidget {
  const _EntrySummaryTile({
    required this.entry,
    required this.onTap,
    this.selected = false,
  });

  final Entry entry;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final preview = _firstTwoLines(entry.content);
    final when = entry.updatedAt.toLocal();
    final timeLabel =
        '${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')} '
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';

    return ListTile(
      selected: selected,
      title: Text(
        entry.title.isEmpty ? S.timelineUntitled : entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        preview.isEmpty ? timeLabel : '$preview\n$timeLabel',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: preview.isNotEmpty,
      onTap: onTap,
    );
  }

  static String _firstTwoLines(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(2)
        .toList();
    return lines.join('\n');
  }
}
