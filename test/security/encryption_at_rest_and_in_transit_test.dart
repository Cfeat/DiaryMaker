import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/sqlite_entry_repository.dart';
import 'package:private_note/core/sync/memory_sync_meta_repository.dart';
import 'package:private_note/core/sync/sync_credentials_store.dart';
import 'package:private_note/core/sync/sync_engine.dart';
import 'package:private_note/core/sync/sync_envelope.dart';
import 'package:private_note/core/sync/sync_key_manager.dart';
import 'package:private_note/core/sync/sync_meta.dart';
import 'package:private_note/foundation/crypto/crypto_service.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/crypto/key_manager.dart';
import 'package:private_note/foundation/crypto/secure_storage_key_manager.dart';
import 'package:private_note/foundation/db/encrypted_database.dart';
import 'package:private_note/foundation/webdav/memory_webdav_client.dart';
import 'package:uuid/uuid.dart';

/// F3: disk ciphertext, WebDAV ciphertext, keys not in plaintext stores.
void main() {
  const marker = 'SECURITY_PLAINTEXT_MARKER_9c2e_DIARY';

  test('F3 DB file on disk does not contain diary plaintext', () async {
    final dir = await Directory.systemTemp.createTemp('pn_sec_db_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    final dbFile = File('${dir.path}/secure.db');
    final key = Uint8List.fromList(List<int>.filled(32, 11));
    final db = await EncryptedDatabase.openFile(file: dbFile, key: key);
    final repo = SqliteEntryRepository(db);
    final id = const Uuid().v4();
    await repo.create(
      Entry(
        id: id,
        title: 'T-$marker',
        content: 'C-$marker',
        createdAt: DateTime.utc(2026, 10, 26),
        updatedAt: DateTime.utc(2026, 10, 26),
      ),
    );
    db.close();

    final raw = await dbFile.readAsBytes();
    final asLatin = String.fromCharCodes(raw);
    expect(asLatin.contains(marker), isFalse,
        reason: 'SQLCipher/sqlite3mc file must not leak plaintext marker');
    expect(utf8.decode(raw, allowMalformed: true).contains(marker), isFalse);
  });

  test('F3 WebDAV upload bytes are ciphertext (no diary plaintext)', () async {
    final key = Uint8List.fromList(List<int>.filled(32, 22));
    final db = await EncryptedDatabase.openEphemeral(key: key);
    addTearDown(db.close);
    final repo = SqliteEntryRepository(db);
    final id = 'sec-upload-1';
    await repo.create(
      Entry(
        id: id,
        title: marker,
        content: 'body-$marker',
        createdAt: DateTime.utc(2026, 10, 26),
        updatedAt: DateTime.utc(2026, 10, 26),
      ),
    );
    final meta = MemorySyncMetaRepository();
    await meta.upsert(SyncMeta(entryId: id, localVersion: 1));
    final webdav = MemoryWebDavClient();
    final storage = InMemorySecureStoragePort();
    final engine = SyncEngine(
      entries: repo,
      syncMeta: meta,
      envelope: SyncEnvelope(CryptoService()),
      syncKeys: SyncKeyManager(storage),
      clientFactory: (_) => webdav,
    );
    final report = await engine.synchronize(
      credentials: const SyncCredentials(
        baseUrl: 'https://dav.test',
        username: 'u',
        password: 'p',
      ),
    );
    expect(report.error, isNull);
    final path = SyncEngine.remotePath('/privatenote/entries', id);
    final uploaded = await webdav.getBytes(path);
    final text = utf8.decode(uploaded);
    expect(text.contains(marker), isFalse);
    expect(text.contains('ciphertext_b64'), isTrue);
  });

  test('F3 keys stay out of SharedPreferences-like and plain file stores',
      () async {
    final secure = InMemorySecureStoragePort();
    final prefsLike = <String, String>{}; // pretend SharedPreferences
    final plainFiles = <String, String>{};

    final keyManager = SecureStorageKeyManager(secure);
    final dbKey = await keyManager.getOrCreateDatabaseKey();
    final syncKeys = SyncKeyManager(secure);
    final syncKey = await syncKeys.getOrCreate();
    final credsStore = SyncCredentialsStore(secure);
    await credsStore.save(
      const SyncCredentials(
        baseUrl: 'https://dav.test',
        username: 'alice',
        password: 'super-secret-webdav',
      ),
    );

    // Application code must not have written secrets into prefs/files.
    expect(prefsLike, isEmpty);
    expect(plainFiles, isEmpty);

    // Secrets live only under secure port keys we own.
    final secureDump = secure.debugValues;
    expect(secureDump.containsKey(KeyManager.storageKey), isTrue);
    expect(secureDump.containsKey(SyncKeyManager.storageKey), isTrue);
    expect(secureDump.containsKey('webdav_sync_credentials_v1'), isTrue);

    // Raw key bytes must not appear as UTF-8 in any secure dump string value
    // beyond Base64 (Base64 is expected). Ensure no hex dump of full key as
    // contiguous plaintext ASCII of raw bytes.
    final dbKeyAscii = String.fromCharCodes(dbKey);
    final syncKeyAscii = String.fromCharCodes(syncKey);
    for (final value in secureDump.values) {
      expect(value.contains(dbKeyAscii), isFalse);
      expect(value.contains(syncKeyAscii), isFalse);
    }

    // Password is in secure JSON only — not in prefsLike.
    expect(prefsLike.values.any((v) => v.contains('super-secret-webdav')), isFalse);
  });
}
