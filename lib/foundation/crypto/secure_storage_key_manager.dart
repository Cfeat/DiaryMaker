import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'key_manager.dart';
import 'secure_storage_port.dart';

typedef DatabaseKeyGenerator = Future<Uint8List> Function();

/// [KeyManager] backed by a [SecureStoragePort] (platform secure storage).
class SecureStorageKeyManager implements KeyManager {
  SecureStorageKeyManager(
    this._storage, {
    DatabaseKeyGenerator? generateKey,
  }) : _generateKey = generateKey ?? defaultGenerateDatabaseKey;

  final SecureStoragePort _storage;
  final DatabaseKeyGenerator _generateKey;

  /// 32-byte key via audited [cryptography] AES-GCM key generation (§2.3).
  static Future<Uint8List> defaultGenerateDatabaseKey() async {
    final secretKey = await AesGcm.with256bits().newSecretKey();
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  @override
  Future<Uint8List> getOrCreateDatabaseKey() async {
    final existing = await _tryReadValidKey();
    if (existing != null) {
      return existing;
    }

    final key = await _generateKey();
    if (key.length != KeyManager.keyLengthBytes) {
      throw StateError(
        'Key generator returned ${key.length} bytes; '
        'expected ${KeyManager.keyLengthBytes}',
      );
    }
    await _storage.write(
      key: KeyManager.storageKey,
      value: base64Encode(key),
    );
    return key;
  }

  @override
  Future<Uint8List?> readDatabaseKey() async {
    return _tryReadValidKey();
  }

  @override
  Future<void> deleteDatabaseKey() async {
    await _storage.delete(key: KeyManager.storageKey);
  }

  /// Missing → null. Corrupt → [KeyCorruptionException] (no silent overwrite).
  Future<Uint8List?> _tryReadValidKey() async {
    final raw = await _storage.read(key: KeyManager.storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return _decodeOrThrow(raw);
  }

  Uint8List _decodeOrThrow(String raw) {
    late final Uint8List bytes;
    try {
      bytes = Uint8List.fromList(base64Decode(raw));
    } on FormatException catch (e) {
      throw KeyCorruptionException(
        'DB key in secure storage is not valid Base64: $e',
      );
    }
    if (bytes.length != KeyManager.keyLengthBytes) {
      throw KeyCorruptionException(
        'DB key length is ${bytes.length}, expected ${KeyManager.keyLengthBytes}',
      );
    }
    return bytes;
  }
}
