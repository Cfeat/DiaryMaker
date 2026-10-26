import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Client-side AES-256-GCM for sync payloads (§2.3).
///
/// Wire format (concatenation): `nonce (12) || cipherText || mac (16)`.
class CryptoService {
  CryptoService({AesGcm? algorithm})
      : _algorithm = algorithm ?? AesGcm.with256bits();

  static const nonceLength = 12;
  static const macLength = 16;
  static const keyLengthBytes = 32;

  final AesGcm _algorithm;

  /// Encrypts [plaintext] with a fresh random nonce (never reused).
  Future<Uint8List> encrypt({
    required Uint8List plaintext,
    required Uint8List key,
  }) async {
    _requireKey(key);
    final secretKey = SecretKey(key);
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    return Uint8List.fromList(box.concatenation());
  }

  /// Decrypts [ciphertext] produced by [encrypt].
  ///
  /// Throws [CryptoTamperException] when the auth tag fails (tamper / wrong key).
  /// Throws [CryptoFormatException] when the blob is truncated or malformed.
  Future<Uint8List> decrypt({
    required Uint8List ciphertext,
    required Uint8List key,
  }) async {
    _requireKey(key);
    if (ciphertext.isEmpty) {
      throw CryptoFormatException('ciphertext must not be empty');
    }
    final minLen = nonceLength + macLength;
    if (ciphertext.length < minLen) {
      throw CryptoFormatException(
        'ciphertext too short (need at least $minLen bytes)',
      );
    }

    final SecretBox box;
    try {
      box = SecretBox.fromConcatenation(
        ciphertext,
        nonceLength: nonceLength,
        macLength: macLength,
      );
    } catch (e) {
      throw CryptoFormatException('invalid ciphertext layout: $e');
    }

    try {
      final clear = await _algorithm.decrypt(
        box,
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError catch (e) {
      throw CryptoTamperException(
        'AES-GCM authentication failed (wrong key or tampered ciphertext): $e',
      );
    }
  }

  void _requireKey(Uint8List key) {
    if (key.length != keyLengthBytes) {
      throw ArgumentError.value(
        key.length,
        'key.length',
        'AES-256-GCM key must be $keyLengthBytes bytes',
      );
    }
  }
}

/// Auth tag verification failed — treat as tamper or wrong key (§2.3).
class CryptoTamperException implements Exception {
  CryptoTamperException(this.message);

  final String message;

  @override
  String toString() => 'CryptoTamperException: $message';
}

/// Ciphertext blob is empty, truncated, or not a valid GCM concatenation.
class CryptoFormatException implements Exception {
  CryptoFormatException(this.message);

  final String message;

  @override
  String toString() => 'CryptoFormatException: $message';
}
