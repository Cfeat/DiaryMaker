import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feature/app_lock/lock_gate.dart';
import '../feature/shell/adaptive_shell.dart';
import '../feature/shell/windows_title_bar.dart';
import 'editor_save_gateway.dart';
import 'l10n/app_strings.dart';
import 'providers.dart';
import 'shell_action_gateway.dart';
import 'theme/appearance_controller.dart';

class PrivateNoteApp extends ConsumerWidget {
  const PrivateNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(appHostProvider);
    final appearance = ref.watch(appearanceControllerProvider);
    final useMeta = defaultTargetPlatform == TargetPlatform.macOS;

    final home = LockGate(
      child: const AdaptiveShell(),
    );

    final material = MaterialApp(
      title: S.appName,
      locale: const Locale('zh', 'CN'),
      theme: appearance.theme,
      shortcuts: host.supportsDesktopShortcuts
          ? <ShortcutActivator, Intent>{
              ...WidgetsApp.defaultShortcuts,
              SingleActivator(
                LogicalKeyboardKey.keyS,
                control: !useMeta,
                meta: useMeta,
              ): const SaveEditorIntent(),
              SingleActivator(
                LogicalKeyboardKey.keyN,
                control: !useMeta,
                meta: useMeta,
              ): const NewEntryIntent(),
              SingleActivator(
                LogicalKeyboardKey.keyL,
                control: !useMeta,
                meta: useMeta,
              ): const FocusTimelineIntent(),
            }
          : null,
      actions: host.supportsDesktopShortcuts
          ? <Type, Action<Intent>>{
              ...WidgetsApp.defaultActions,
              SaveEditorIntent: CallbackAction<SaveEditorIntent>(
                onInvoke: (intent) {
                  ref.read(editorSaveGatewayProvider).requestSave();
                  return null;
                },
              ),
              NewEntryIntent: CallbackAction<NewEntryIntent>(
                onInvoke: (intent) {
                  ref.read(shellActionGatewayProvider).requestNewEntry();
                  return null;
                },
              ),
              FocusTimelineIntent: CallbackAction<FocusTimelineIntent>(
                onInvoke: (intent) {
                  ref.read(shellActionGatewayProvider).requestFocusTimeline();
                  return null;
                },
              ),
            }
          : null,
      home: host.usesCustomWindowChrome
          ? _WindowsChromeShell(child: home)
          : home,
    );

    return material;
  }
}

class _WindowsChromeShell extends StatelessWidget {
  const _WindowsChromeShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const WindowsTitleBar(title: S.appName),
        Expanded(child: child),
      ],
    );
  }
}
