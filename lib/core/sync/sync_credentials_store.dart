import 'dart:convert';

import '../../foundation/crypto/secure_storage_port.dart';

/// WebDAV settings. Password never written to SharedPreferences (§2.4 spirit).
class SyncCredentials {
  const SyncCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.remoteRoot = '/privatenote/entries',
  });

  final String baseUrl;
  final String username;
  final String password;
  final String remoteRoot;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;
}

class SyncCredentialsStore {
  SyncCredentialsStore(this._storage);

  static const _storageKey = 'webdav_sync_credentials_v1';

  final SecureStoragePort _storage;

  Future<void> save(SyncCredentials credentials) async {
    final payload = jsonEncode({
      'base_url': credentials.baseUrl.trim(),
      'username': credentials.username.trim(),
      'password': credentials.password,
      'remote_root': credentials.remoteRoot.trim(),
    });
    await _storage.write(key: _storageKey, value: payload);
  }

  Future<SyncCredentials?> read() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return SyncCredentials(
      baseUrl: map['base_url'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      remoteRoot: map['remote_root'] as String? ?? '/privatenote/entries',
    );
  }

  Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }
}
