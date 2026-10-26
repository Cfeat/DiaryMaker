import '../../foundation/crypto/pin_hasher.dart';
import '../../foundation/crypto/secure_storage_port.dart';
import '../../foundation/platform/biometric_auth.dart';

enum AppLockPhase {
  /// Cold start / loading PIN presence.
  loading,

  /// First launch: user must set a PIN before any diary UI.
  needsSetup,

  /// PIN (and optional biometric) required.
  locked,

  /// Authenticated for this session.
  unlocked,
}

class AppLockState {
  const AppLockState({
    required this.phase,
    this.errorMessage,
    this.failedAttempts = 0,
    this.lockoutUntil,
    this.biometricsAvailable = false,
  });

  final AppLockPhase phase;
  final String? errorMessage;
  final int failedAttempts;
  final DateTime? lockoutUntil;
  final bool biometricsAvailable;

  bool isLockedOutAt(DateTime now) {
    final until = lockoutUntil;
    if (until == null) return false;
    return now.isBefore(until);
  }

  /// Wall-clock convenience for UI (tests inject clock via [AppLockService]).
  bool get isLockedOut => isLockedOutAt(DateTime.now());

  Duration? remainingLockoutAt(DateTime now) {
    final until = lockoutUntil;
    if (until == null) return null;
    final left = until.difference(now);
    if (left.isNegative) return null;
    return left;
  }

  Duration? get remainingLockout => remainingLockoutAt(DateTime.now());

  AppLockState copyWith({
    AppLockPhase? phase,
    String? errorMessage,
    bool clearError = false,
    int? failedAttempts,
    DateTime? lockoutUntil,
    bool clearLockout = false,
    bool? biometricsAvailable,
  }) {
    return AppLockState(
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
      biometricsAvailable:
          biometricsAvailable ?? this.biometricsAvailable,
    );
  }
}

/// App-level access lock: PIN on all platforms; biometrics on mobile (section 2.5).
///
/// Functional equivalent of `secure_app_locker` for PIN + resume lock + backoff.
/// That package (pub.dev) currently lacks app-level PIN (roadmap v1.3) and
/// dedicated desktop PIN - so we own PIN storage (secure storage) and policy.
class AppLockService {
  AppLockService({
    required this.storage,
    required this.biometricAuth,
    required this.biometricsEnabledByHost,
    PinHasher? pinHasher,
    this.maxAttemptsBeforeBackoff = 3,
    DateTime Function()? clock,
  })  : _hasher = pinHasher ?? PinHasher(),
        _clock = clock ?? DateTime.now;

  static const pinStorageKey = 'app_lock_pin_hash';

  final SecureStoragePort storage;
  final BiometricAuth biometricAuth;
  final bool biometricsEnabledByHost;
  final PinHasher _hasher;
  final int maxAttemptsBeforeBackoff;
  final DateTime Function() _clock;

  AppLockState _state = const AppLockState(phase: AppLockPhase.loading);
  final List<void Function(AppLockState)> _listeners = [];

  AppLockState get state => _state;

  void addListener(void Function(AppLockState) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(AppLockState) listener) {
    _listeners.remove(listener);
  }

  void _emit(AppLockState next) {
    _state = next;
    for (final l in List.of(_listeners)) {
      l(_state);
    }
  }

  Future<void> initialize() async {
    final stored = await storage.read(key: pinStorageKey);
    final bio = biometricsEnabledByHost && await biometricAuth.isAvailable;
    if (stored == null || stored.isEmpty) {
      _emit(
        AppLockState(
          phase: AppLockPhase.needsSetup,
          biometricsAvailable: bio,
        ),
      );
    } else {
      _emit(
        AppLockState(
          phase: AppLockPhase.locked,
          biometricsAvailable: bio,
        ),
      );
    }
  }

  /// Call when app resumes from background ??re-lock if a PIN is configured.
  Future<void> onAppResumed() async {
    final stored = await storage.read(key: pinStorageKey);
    if (stored == null || stored.isEmpty) return;
    if (_state.phase == AppLockPhase.unlocked ||
        _state.phase == AppLockPhase.locked) {
      _emit(
        _state.copyWith(
          phase: AppLockPhase.locked,
          clearError: true,
        ),
      );
    }
  }

  Future<void> setupPin(String pin) async {
    _validatePinFormat(pin);
    final digest = await _hasher.hashPin(pin);
    await storage.write(key: pinStorageKey, value: digest);
    _emit(
      _state.copyWith(
        phase: AppLockPhase.unlocked,
        failedAttempts: 0,
        clearError: true,
        clearLockout: true,
      ),
    );
  }

  bool _lockedOutNow() => _state.isLockedOutAt(_clock());

  Future<bool> unlockWithPin(String pin) async {
    if (_lockedOutNow()) {
      _emit(
        _state.copyWith(
          errorMessage: 'Too many attempts. Try again later.',
        ),
      );
      return false;
    }

    final stored = await storage.read(key: pinStorageKey);
    if (stored == null) {
      _emit(_state.copyWith(phase: AppLockPhase.needsSetup, clearError: true));
      return false;
    }

    final ok = await _hasher.verifyPin(pin, stored);
    if (ok) {
      _emit(
        _state.copyWith(
          phase: AppLockPhase.unlocked,
          failedAttempts: 0,
          clearError: true,
          clearLockout: true,
        ),
      );
      return true;
    }

    final attempts = _state.failedAttempts + 1;
    DateTime? lockout;
    String? error = 'Incorrect PIN';
    if (attempts >= maxAttemptsBeforeBackoff) {
      final delaySeconds = _backoffSeconds(attempts);
      lockout = _clock().add(Duration(seconds: delaySeconds));
      error = 'Incorrect PIN. Locked for ${delaySeconds}s.';
    }
    _emit(
      _state.copyWith(
        failedAttempts: attempts,
        lockoutUntil: lockout,
        errorMessage: error,
      ),
    );
    return false;
  }

  Future<bool> unlockWithBiometrics({
    String reason = 'Unlock PrivateNote',
  }) async {
    if (!_state.biometricsAvailable) return false;
    if (_lockedOutNow()) {
      _emit(
        _state.copyWith(
          errorMessage: 'Too many attempts. Try again later.',
        ),
      );
      return false;
    }
    final ok = await biometricAuth.authenticate(reason: reason);
    if (ok) {
      _emit(
        _state.copyWith(
          phase: AppLockPhase.unlocked,
          failedAttempts: 0,
          clearError: true,
          clearLockout: true,
        ),
      );
    }
    return ok;
  }

  void lock() {
    if (_state.phase == AppLockPhase.needsSetup ||
        _state.phase == AppLockPhase.loading) {
      return;
    }
    _emit(
      _state.copyWith(phase: AppLockPhase.locked, clearError: true),
    );
  }

  void _validatePinFormat(String pin) {
    if (pin.length < 4 || pin.length > 8) {
      throw ArgumentError('PIN must be 4?? digits');
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      throw ArgumentError('PIN must be numeric');
    }
  }

  /// Exponential backoff after [maxAttemptsBeforeBackoff] failures.
  int _backoffSeconds(int attempts) {
    final excess = attempts - maxAttemptsBeforeBackoff + 1;
    final seconds = 1 << (excess.clamp(0, 5));
    return seconds.clamp(1, 60);
  }
}
