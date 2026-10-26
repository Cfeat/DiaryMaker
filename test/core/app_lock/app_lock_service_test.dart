import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/app_lock/app_lock_service.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/crypto/pin_hasher.dart';
import 'package:private_note/foundation/platform/biometric_auth.dart';

void main() {
  late InMemorySecureStoragePort storage;
  late AppLockService service;
  var now = DateTime.utc(2026, 10, 26, 12);

  setUp(() {
    storage = InMemorySecureStoragePort();
    now = DateTime.utc(2026, 10, 26, 12);
    service = AppLockService(
      storage: storage,
      biometricAuth: const NoOpBiometricAuth(),
      biometricsEnabledByHost: false,
      pinHasher: PinHasher(iterations: PinHasher.testIterations),
      clock: () => now,
      maxAttemptsBeforeBackoff: 3,
    );
  });

  test('setup then unlock with correct PIN', () async {
    await service.initialize();
    expect(service.state.phase, AppLockPhase.needsSetup);
    await service.setupPin('1234');
    expect(service.state.phase, AppLockPhase.unlocked);

    service.lock();
    expect(service.state.phase, AppLockPhase.locked);
    expect(await service.unlockWithPin('1234'), isTrue);
    expect(service.state.phase, AppLockPhase.unlocked);
  });

  test('failed attempts trigger backoff delay', () async {
    await service.setupPin('1234');
    service.lock();

    expect(await service.unlockWithPin('0000'), isFalse);
    expect(await service.unlockWithPin('0000'), isFalse);
    expect(await service.unlockWithPin('0000'), isFalse);
    expect(service.state.isLockedOutAt(now), isTrue);
    expect(service.state.lockoutUntil, isNotNull);

    expect(await service.unlockWithPin('1234'), isFalse);

    now = now.add(const Duration(seconds: 5));
    expect(service.state.isLockedOutAt(now), isFalse);
    expect(await service.unlockWithPin('1234'), isTrue);
  });

  test('onAppResumed re-locks when PIN configured', () async {
    await service.setupPin('9999');
    expect(service.state.phase, AppLockPhase.unlocked);
    await service.onAppResumed();
    expect(service.state.phase, AppLockPhase.locked);
  });
}
