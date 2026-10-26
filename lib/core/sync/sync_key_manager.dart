import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../foundation/crypto/crypto_service.dart';
import '../../foundation/crypto/secure_storage_port.dart';

/// AES-256 sync key, separate from DB key; stored only in secure storage (§2.4).
class SyncKeyManager {
  SyncKeyManager(this._storage);

  static const storageKey = 'sync_e2e_aes256_key';

  final SecureStoragePort _storage;

  Future<Uint8List> getOrCreate() async {
    final existing = await read();
    if (existing != null) return existing;
    final secret = await AesGcm.with256bits().newSecretKey();
    final bytes = Uint8List.fromList(await secret.extractBytes());
    if (bytes.length != CryptoService.keyLengthBytes) {
      throw StateError('unexpected sync key length ${bytes.length}');
    }
    await _storage.write(key: storageKey, value: base64Encode(bytes));
    return bytes;
  }

  Future<Uint8List?> read() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null || raw.isEmpty) return null;
    final bytes = base64Decode(raw);
    if (bytes.length != CryptoService.keyLengthBytes) return null;
    return Uint8List.fromList(bytes);
  }

  /// Test / multi-device restore helper.
  Future<void> importKey(Uint8List key) async {
    if (key.length != CryptoService.keyLengthBytes) {
      throw ArgumentError('sync key must be 32 bytes');
    }
    await _storage.write(key: storageKey, value: base64Encode(key));
  }
}
