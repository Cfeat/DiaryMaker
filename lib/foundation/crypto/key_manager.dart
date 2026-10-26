import 'dart:typed_data';

/// Manages the SQLCipher / sqlite3mc database encryption key.
///
/// The key is 32 cryptographically secure random bytes, stored only in
/// platform secure storage. It is **not** derived from the user PIN (§2.4 / B1).
abstract class KeyManager {
  /// Storage key name for the DB encryption key material (Base64).
  static const storageKey = 'db_encryption_key';

  static const keyLengthBytes = 32;

  /// Returns the existing key, or generates and persists a new one if absent.
  Future<Uint8List> getOrCreateDatabaseKey();

  /// Reads the key if present; returns null when missing (not an error).
  Future<Uint8List?> readDatabaseKey();

  /// Deletes the stored key (factory reset / wipe). Does not touch the DB file.
  Future<void> deleteDatabaseKey();
}

/// Stored value exists but cannot be decoded into a valid 32-byte key.
class KeyCorruptionException implements Exception {
  KeyCorruptionException(this.message);

  final String message;

  @override
  String toString() => 'KeyCorruptionException: $message';
}

/// Key is required to open an existing DB but is missing or unusable.
/// Callers must not silently mint a new key over an existing encrypted file.
class DbKeyUnavailableException implements Exception {
  DbKeyUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'DbKeyUnavailableException: $message';
}
