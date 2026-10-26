/// Narrow port over platform secure storage (Keystore / Keychain / Credential Manager).
///
/// Keeps [KeyManager] testable without platform channels.
abstract class SecureStoragePort {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});
}
