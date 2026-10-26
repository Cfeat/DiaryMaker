import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../app/shell_action_gateway.dart';
import '../../core/entry/entry.dart';
import '../../foundation/platform/layout_breakpoints.dart';
import '../editor/editor_page.dart';
import '../timeline/timeline_page.dart';

/// Width ≥ [LayoutBreakpoints.splitMinWidth]: sidebar + editor.
/// Narrower: single-stack timeline (phone / narrow window).
class AdaptiveShell extends ConsumerStatefulWidget {
  const AdaptiveShell({super.key});

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  Entry? _selected;
  var _composingNew = false;

  late final VoidCallback _focusTimelineHandler;
  late final ShellActionGateway _shellActions;
  final _timelineFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusTimelineHandler = () => _timelineFocus.requestFocus();
    _shellActions = ref.read(shellActionGatewayProvider);
    _shellActions.registerFocusTimeline(_focusTimelineHandler);
  }

  @override
  void dispose() {
    _shellActions.unregisterFocusTimeline(_focusTimelineHandler);
    _timelineFocus.dispose();
    super.dispose();
  }

  void _composeNew() {
    setState(() {
      _selected = null;
      _composingNew = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final useSplit = LayoutBreakpoints.useSplitLayout(context);

    if (useSplit) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 320,
              child: Material(
                elevation: 1,
                child: TimelinePage(
                  embedded: true,
                  listFocusNode: _timelineFocus,
                  onComposeNew: _composeNew,
                  onOpenEntry: (entry) {
                    setState(() {
                      _selected = entry;
                      _composingNew = false;
                    });
                  },
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _composingNew
                  ? EditorPage(
                      key: const ValueKey('new'),
                      embedded: true,
                      onSaved: () {
                        setState(() => _composingNew = false);
                        ref.read(timelineEntriesProvider.notifier).refresh();
                      },
                    )
                  : _selected == null
                      ? const Center(
                          child: Text(S.selectOrCreate),
                        )
                      : EditorPage(
                          key: ValueKey(_selected!.id),
                          entryId: _selected!.id,
                          embedded: true,
                          onSaved: () {
                            ref.read(timelineEntriesProvider.notifier).refresh();
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('shell_new_entry'),
          onPressed: _composeNew,
          child: const Icon(Icons.add),
        ),
      );
    }

    return TimelinePage(listFocusNode: _timelineFocus);
  }
}
