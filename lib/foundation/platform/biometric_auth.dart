/// Narrow port for biometric / OS local auth (mobile).
abstract class BiometricAuth {
  Future<bool> get isAvailable;

  /// Prompts the user; returns true on success.
  Future<bool> authenticate({required String reason});
}

class NoOpBiometricAuth implements BiometricAuth {
  const NoOpBiometricAuth();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}
