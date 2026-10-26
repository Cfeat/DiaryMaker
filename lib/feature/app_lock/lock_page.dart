import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n/app_strings.dart';
import '../../app/providers.dart';
import '../../core/app_lock/app_lock_service.dart';

/// PIN 设置 / 解锁。不展示日记内容（§2.5）。
class LockPage extends ConsumerStatefulWidget {
  const LockPage({super.key});

  @override
  ConsumerState<LockPage> createState() => _LockPageState();
}

class _LockPageState extends ConsumerState<LockPage> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockStateProvider);
    final isSetup = lock.phase == AppLockPhase.needsSetup;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.primary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 48,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.appName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSetup ? S.lockSetupHint : S.lockEnterHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      key: const Key('lock_pin_field'),
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      enabled: !_busy && !lock.isLockedOut,
                      decoration: InputDecoration(
                        labelText: isSetup ? S.lockNewPin : S.lockPin,
                      ),
                      onSubmitted: (_) => _submit(isSetup),
                    ),
                    if (isSetup) ...[
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('lock_pin_confirm_field'),
                        controller: _confirmController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: S.lockConfirmPin,
                        ),
                        onSubmitted: (_) => _submit(true),
                      ),
                    ],
                    if (lock.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        lock.errorMessage!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    if (lock.isLockedOut && lock.remainingLockout != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        S.lockWaitSeconds(lock.remainingLockout!.inSeconds),
                        key: const Key('lock_backoff_label'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('lock_submit_button'),
                        onPressed: (_busy || lock.isLockedOut)
                            ? null
                            : () => _submit(isSetup),
                        child: Text(isSetup ? S.lockSavePin : S.lockUnlock),
                      ),
                    ),
                    if (!isSetup && lock.biometricsAvailable) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        key: const Key('lock_biometric_button'),
                        onPressed: _busy ? null : _biometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text(S.lockUseBiometrics),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(bool isSetup) async {
    final pin = _pinController.text;
    setState(() => _busy = true);
    try {
      if (isSetup) {
        if (pin != _confirmController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(S.lockPinMismatch)),
          );
          return;
        }
        await ref.read(appLockStateProvider.notifier).setupPin(pin);
      } else {
        await ref.read(appLockStateProvider.notifier).unlockWithPin(pin);
        _pinController.clear();
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? S.lockInvalidPin)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    setState(() => _busy = true);
    try {
      await ref.read(appLockStateProvider.notifier).unlockWithBiometrics();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
