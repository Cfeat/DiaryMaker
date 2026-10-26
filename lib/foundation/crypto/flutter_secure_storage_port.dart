import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_port.dart';

/// [SecureStoragePort] over [FlutterSecureStorage].
class FlutterSecureStoragePort implements SecureStoragePort {
  FlutterSecureStoragePort(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }
}
