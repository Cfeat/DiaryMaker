import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/crypto/key_manager.dart';
import 'package:private_note/foundation/crypto/platform_key_managers.dart';
import 'package:private_note/foundation/crypto/secure_storage_key_manager.dart';

void main() {
  group('SecureStorageKeyManager — normal read', () {
    test('returns persisted 32-byte key', () async {
      final storage = InMemorySecureStoragePort();
      final expected = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await storage.write(
        key: KeyManager.storageKey,
        value: base64Encode(expected),
      );
      final manager = SecureStorageKeyManager(storage);

      final key = await manager.readDatabaseKey();

      expect(key, isNotNull);
      expect(key, hasLength(32));
      expect(key, orderedEquals(expected));
    });

    test('getOrCreate returns same key on second call', () async {
      final storage = InMemorySecureStoragePort();
      var generations = 0;
      final manager = SecureStorageKeyManager(
        storage,
        generateKey: () async {
          generations++;
          return Uint8List.fromList(List<int>.filled(32, generations));
        },
      );

      final first = await manager.getOrCreateDatabaseKey();
      final second = await manager.getOrCreateDatabaseKey();

      expect(generations, 1);
      expect(first, orderedEquals(second));
      expect(first, hasLength(32));
    });

    test('platform subclasses share SecureStorageKeyManager behavior', () async {
      final storage = InMemorySecureStoragePort();
      final managers = <KeyManager>[
        AndroidKeyManager(storage: storage),
        IosKeyManager(storage: storage),
        MacOsKeyManager(storage: storage),
        WindowsKeyManager(storage: storage),
      ];

      // Seed once via first manager; others must read the same material.
      final seeded = await SecureStorageKeyManager(
        storage,
        generateKey: () async => Uint8List.fromList(List<int>.filled(32, 7)),
      ).getOrCreateDatabaseKey();

      for (final m in managers) {
        expect(await m.readDatabaseKey(), orderedEquals(seeded));
      }
    });
  });

  group('SecureStorageKeyManager — init when key missing', () {
    test('getOrCreate generates and stores a new key', () async {
      final storage = InMemorySecureStoragePort();
      final generated = Uint8List.fromList(List<int>.generate(32, (i) => 100 + i));
      final manager = SecureStorageKeyManager(
        storage,
        generateKey: () async => generated,
      );

      expect(await manager.readDatabaseKey(), isNull);

      final key = await manager.getOrCreateDatabaseKey();

      expect(key, orderedEquals(generated));
      expect(storage.debugValues[KeyManager.storageKey], base64Encode(generated));
    });

    test('readDatabaseKey returns null when storage empty', () async {
      final manager = SecureStorageKeyManager(InMemorySecureStoragePort());
      expect(await manager.readDatabaseKey(), isNull);
    });

    test('rejects generator that returns wrong length', () async {
      final manager = SecureStorageKeyManager(
        InMemorySecureStoragePort(),
        generateKey: () async => Uint8List(16),
      );

      expect(manager.getOrCreateDatabaseKey(), throwsA(isA<StateError>()));
    });
  });

  group('SecureStorageKeyManager — corruption / degradation', () {
    test('throws KeyCorruptionException on invalid Base64', () async {
      final storage = InMemorySecureStoragePort();
      await storage.write(key: KeyManager.storageKey, value: '%%%not-base64%%%');
      final manager = SecureStorageKeyManager(storage);

      expect(
        manager.readDatabaseKey(),
        throwsA(isA<KeyCorruptionException>()),
      );
      expect(
        manager.getOrCreateDatabaseKey(),
        throwsA(isA<KeyCorruptionException>()),
      );
      // Must not overwrite corrupt material during getOrCreate.
      expect(storage.debugValues[KeyManager.storageKey], '%%%not-base64%%%');
    });

    test('throws KeyCorruptionException when length is not 32 bytes', () async {
      final storage = InMemorySecureStoragePort();
      await storage.write(
        key: KeyManager.storageKey,
        value: base64Encode(Uint8List(8)),
      );
      final manager = SecureStorageKeyManager(storage);

      expect(
        manager.readDatabaseKey(),
        throwsA(
          isA<KeyCorruptionException>().having(
            (e) => e.message,
            'message',
            contains('expected 32'),
          ),
        ),
      );
    });

    test('deleteDatabaseKey clears storage so getOrCreate can mint again', () async {
      final storage = InMemorySecureStoragePort();
      final manager = SecureStorageKeyManager(
        storage,
        generateKey: () async => Uint8List.fromList(List<int>.filled(32, 1)),
      );
      await manager.getOrCreateDatabaseKey();
      await manager.deleteDatabaseKey();

      expect(await manager.readDatabaseKey(), isNull);

      final regenerated = await SecureStorageKeyManager(
        storage,
        generateKey: () async => Uint8List.fromList(List<int>.filled(32, 2)),
      ).getOrCreateDatabaseKey();

      expect(regenerated.first, 2);
    });
  });

  group('SecureStorageKeyManager — deleteDatabaseKey', () {
    test('normal — removes existing key', () async {
      final storage = InMemorySecureStoragePort();
      final manager = SecureStorageKeyManager(storage);
      await manager.getOrCreateDatabaseKey();
      expect(await manager.readDatabaseKey(), isNotNull);
      await manager.deleteDatabaseKey();
      expect(await manager.readDatabaseKey(), isNull);
    });

    test('boundary — delete when already empty is a no-op', () async {
      final storage = InMemorySecureStoragePort();
      final manager = SecureStorageKeyManager(storage);
      await manager.deleteDatabaseKey();
      expect(await manager.readDatabaseKey(), isNull);
    });

    test('exception path — after delete, corrupt write still throws on read',
        () async {
      final storage = InMemorySecureStoragePort();
      final manager = SecureStorageKeyManager(storage);
      await manager.deleteDatabaseKey();
      await storage.write(key: KeyManager.storageKey, value: '!!!not-b64!!!');
      expect(
        () => manager.readDatabaseKey(),
        throwsA(isA<KeyCorruptionException>()),
      );
    });
  });

  group('DbKeyUnavailableException contract', () {
    test('message is preserved for UI / recovery flows', () {
      const msg = 'DB exists but secure key is missing';
      final e = DbKeyUnavailableException(msg);
      expect(e.message, msg);
      expect(e.toString(), contains(msg));
    });
  });
}
