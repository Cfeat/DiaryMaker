import 'secure_storage_port.dart';

/// In-memory [SecureStoragePort] for unit tests.
class InMemorySecureStoragePort implements SecureStoragePort {
  final Map<String, String> _values = {};

  Map<String, String> get debugValues => Map.unmodifiable(_values);

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}
