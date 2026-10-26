import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// PIN → salted PBKDF2 digest using audited `package:cryptography` (§2.3).
class PinHasher {
  PinHasher({
    Random? random,
    this.iterations = defaultIterations,
  }) : _random = random ?? Random.secure();

  /// Production iteration count.
  static const defaultIterations = 100000;

  /// Fast hash for widget/unit tests only.
  static const testIterations = 1000;

  static const _saltLength = 16;
  static const _bits = 256;

  final Random _random;
  final int iterations;

  Pbkdf2 get _algorithm => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: _bits,
      );

  Future<String> hashPin(String pin) async {
    final salt = Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => _random.nextInt(256)),
    );
    final hash = await _derive(pin, salt);
    return '${base64Encode(salt)}.${base64Encode(hash)}';
  }

  Future<bool> verifyPin(String pin, String stored) async {
    final parts = stored.split('.');
    if (parts.length != 2) return false;
    final salt = base64Decode(parts[0]);
    final expected = base64Decode(parts[1]);
    final actual = await _derive(pin, salt);
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  Future<Uint8List> _derive(String pin, List<int> salt) async {
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
  }
}
