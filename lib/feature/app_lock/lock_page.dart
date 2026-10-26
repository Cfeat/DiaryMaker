import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/app_lock/app_lock_service.dart';

/// PIN setup / unlock UI. Never shows diary content (§2.5 / DESIGN-SPECS §2).
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'PrivateNote',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSetup ? 'Set a PIN to protect your diary' : 'Enter PIN',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
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
                      labelText: isSetup ? 'New PIN (4–8 digits)' : 'PIN',
                      border: const OutlineInputBorder(),
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
                        labelText: 'Confirm PIN',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(true),
                    ),
                  ],
                  if (lock.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      lock.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (lock.isLockedOut && lock.remainingLockout != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Wait ${lock.remainingLockout!.inSeconds}s',
                      key: const Key('lock_backoff_label'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('lock_submit_button'),
                    onPressed: (_busy || lock.isLockedOut)
                        ? null
                        : () => _submit(isSetup),
                    child: Text(isSetup ? 'Save PIN' : 'Unlock'),
                  ),
                  if (!isSetup && lock.biometricsAvailable) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      key: const Key('lock_biometric_button'),
                      onPressed: _busy ? null : _biometric,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Use biometrics'),
                    ),
                  ],
                ],
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
            const SnackBar(content: Text('PINs do not match')),
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
          SnackBar(content: Text(e.message ?? 'Invalid PIN')),
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
