import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/foundation/crypto/crypto_service.dart';

Uint8List _key([int fill = 7]) =>
    Uint8List.fromList(List<int>.filled(CryptoService.keyLengthBytes, fill));

void main() {
  late CryptoService crypto;

  setUp(() {
    crypto = CryptoService();
  });

  group('encrypt/decrypt happy path', () {
    test('round-trips UTF-8 payload', () async {
      final key = _key();
      final plain = Uint8List.fromList(utf8.encode('hello diary'));
      final cipher = await crypto.encrypt(plaintext: plain, key: key);
      expect(cipher, isNot(equals(plain)));
      expect(
        cipher.length,
        greaterThanOrEqualTo(
          CryptoService.nonceLength + plain.length + CryptoService.macLength,
        ),
      );

      final back = await crypto.decrypt(ciphertext: cipher, key: key);
      expect(utf8.decode(back), 'hello diary');
    });

    test('empty plaintext encrypts and decrypts', () async {
      final key = _key(3);
      final plain = Uint8List(0);
      final cipher = await crypto.encrypt(plaintext: plain, key: key);
      expect(cipher.length, CryptoService.nonceLength + CryptoService.macLength);
      final back = await crypto.decrypt(ciphertext: cipher, key: key);
      expect(back, isEmpty);
    });

    test('each encrypt uses a distinct nonce', () async {
      final key = _key();
      final plain = Uint8List.fromList([1, 2, 3]);
      final a = await crypto.encrypt(plaintext: plain, key: key);
      final b = await crypto.encrypt(plaintext: plain, key: key);
      expect(a, isNot(equals(b)));
      final nonceA = a.sublist(0, CryptoService.nonceLength);
      final nonceB = b.sublist(0, CryptoService.nonceLength);
      expect(nonceA, isNot(equals(nonceB)));
    });
  });

  group('failure modes', () {
    test('wrong key fails with CryptoTamperException', () async {
      final plain = Uint8List.fromList(utf8.encode('secret'));
      final cipher = await crypto.encrypt(plaintext: plain, key: _key(1));
      expect(
        () => crypto.decrypt(ciphertext: cipher, key: _key(2)),
        throwsA(isA<CryptoTamperException>()),
      );
    });

    test('tampered ciphertext fails with CryptoTamperException', () async {
      final key = _key();
      final cipher = await crypto.encrypt(
        plaintext: Uint8List.fromList(utf8.encode('tamper-me')),
        key: key,
      );
      final mutated = Uint8List.fromList(cipher);
      // Flip a byte in the ciphertext region (after nonce).
      final flipAt = CryptoService.nonceLength;
      mutated[flipAt] = mutated[flipAt] ^ 0xff;

      expect(
        () => crypto.decrypt(ciphertext: mutated, key: key),
        throwsA(isA<CryptoTamperException>()),
      );
    });

    test('empty ciphertext throws CryptoFormatException', () async {
      expect(
        () => crypto.decrypt(ciphertext: Uint8List(0), key: _key()),
        throwsA(isA<CryptoFormatException>()),
      );
    });

    test('truncated ciphertext throws CryptoFormatException', () async {
      expect(
        () => crypto.decrypt(
          ciphertext: Uint8List(CryptoService.nonceLength),
          key: _key(),
        ),
        throwsA(isA<CryptoFormatException>()),
      );
    });

    test('invalid key length rejected', () async {
      expect(
        () => crypto.encrypt(
          plaintext: Uint8List(0),
          key: Uint8List(16),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => crypto.decrypt(
          ciphertext: Uint8List(32),
          key: Uint8List(16),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
