import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_lock/app_lock_service.dart';
import 'lock_page.dart';

/// Shows [lockedChild] only when unlocked; otherwise [LockPage].
/// Re-locks on resume from background.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({
    super.key,
    required this.child,
  });

  /// Content revealed after unlock (e.g. adaptive shell / home).
  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock only when actually backgrounded. Do not use `inactive` (transient
    // focus loss) or unconditional `resumed` re-lock (would lock right after
    // a successful unlock / first frame).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final phase = ref.read(appLockStateProvider).phase;
      if (phase == AppLockPhase.unlocked) {
        ref.read(appLockStateProvider.notifier).lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(appLockStateProvider).phase;
    switch (phase) {
      case AppLockPhase.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AppLockPhase.needsSetup:
      case AppLockPhase.locked:
        return const LockPage();
      case AppLockPhase.unlocked:
        return widget.child;
    }
  }
}
