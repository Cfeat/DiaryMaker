import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/memory_entry_repository.dart';
import 'package:private_note/core/sync/memory_sync_meta_repository.dart';
import 'package:private_note/core/sync/sync_conflict_policy.dart';
import 'package:private_note/core/sync/sync_credentials_store.dart';
import 'package:private_note/core/sync/sync_engine.dart';
import 'package:private_note/core/sync/sync_envelope.dart';
import 'package:private_note/core/sync/sync_key_manager.dart';
import 'package:private_note/core/sync/sync_meta.dart';
import 'package:private_note/foundation/crypto/crypto_service.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/webdav/memory_webdav_client.dart';

/// Integration: real [CryptoService], mock WebDAV only.
void main() {
  late MemoryEntryRepository entries;
  late MemorySyncMetaRepository meta;
  late MemoryWebDavClient webdav;
  late SyncKeyManager keys;
  late SyncEngine engine;
  late CryptoService crypto;
  late DateTime now;
  const creds = SyncCredentials(
    baseUrl: 'https://example.test/dav',
    username: 'u',
    password: 'p',
    remoteRoot: '/privatenote/entries',
  );

  setUp(() async {
    entries = MemoryEntryRepository();
    meta = MemorySyncMetaRepository();
    webdav = MemoryWebDavClient();
    final storage = InMemorySecureStoragePort();
    keys = SyncKeyManager(storage);
    crypto = CryptoService();
    now = DateTime.utc(2026, 10, 26, 12);
    engine = SyncEngine(
      entries: entries,
      syncMeta: meta,
      envelope: SyncEnvelope(crypto),
      syncKeys: keys,
      clientFactory: (_) => webdav,
      clock: () => now,
    );
  });

  Entry sample({
    required String id,
    required String title,
    required String content,
    required DateTime updatedAt,
  }) {
    return Entry(
      id: id,
      title: title,
      content: content,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  test('push uploads ciphertext that is not plaintext JSON', () async {
    await entries.create(
      sample(
        id: 'e1',
        title: 'SecretTitle',
        content: 'SecretBody',
        updatedAt: DateTime.utc(2026, 10, 26, 12),
      ),
    );
    await meta.upsert(const SyncMeta(entryId: 'e1', localVersion: 1));

    final report = await engine.synchronize(credentials: creds);
    expect(report.error, isNull);
    expect(report.results.single.action, SyncAction.pushed);

    final path = SyncEngine.remotePath('/privatenote/entries', 'e1');
    final blob = await webdav.getBytes(path);
    final asText = utf8.decode(blob);
    expect(asText.contains('SecretTitle'), isFalse);
    expect(asText.contains('SecretBody'), isFalse);
    expect(asText.contains('ciphertext_b64'), isTrue);

    final key = await keys.getOrCreate();
    final opened = await SyncEnvelope(crypto).open(
      fileBytes: blob,
      syncKey: key,
    );
    expect(opened.entry.title, 'SecretTitle');
    expect(opened.entry.content, 'SecretBody');
  });

  test('second device pull decrypts with shared sync key', () async {
    await entries.create(
      sample(
        id: 'e2',
        title: 'Shared',
        content: 'Hello',
        updatedAt: DateTime.utc(2026, 10, 26, 10),
      ),
    );
    await meta.upsert(const SyncMeta(entryId: 'e2', localVersion: 1));
    await engine.synchronize(credentials: creds);

    final sharedKey = await keys.read();
    expect(sharedKey, isNotNull);

    final entriesB = MemoryEntryRepository();
    final metaB = MemorySyncMetaRepository();
    final storageB = InMemorySecureStoragePort();
    final keysB = SyncKeyManager(storageB);
    await keysB.importKey(sharedKey!);
    final engineB = SyncEngine(
      entries: entriesB,
      syncMeta: metaB,
      envelope: SyncEnvelope(CryptoService()),
      syncKeys: keysB,
      clientFactory: (_) => webdav,
      clock: () => DateTime.utc(2026, 10, 26, 16),
    );

    final report = await engineB.synchronize(credentials: creds);
    expect(report.error, isNull);
    expect(report.results.single.action, SyncAction.pulled);
    final pulled = await entriesB.getById('e2');
    expect(pulled?.title, 'Shared');
    expect(pulled?.content, 'Hello');
  });

  test('both sides changed since last sync → conflict_flag', () async {
    final t0 = DateTime.utc(2026, 10, 26, 10);
    await entries.create(
      sample(id: 'c1', title: 'A', content: 'local-0', updatedAt: t0),
    );
    await meta.upsert(const SyncMeta(entryId: 'c1', localVersion: 1));
    await engine.synchronize(credentials: creds);

    final afterPush = await meta.getByEntryId('c1');
    expect(afterPush?.lastSyncAt, isNotNull);
    expect(afterPush?.remoteEtag, isNotNull);

    // Both edits must be strictly after last_sync_at (12:00 in this harness).
    await entries.update(
      sample(
        id: 'c1',
        title: 'A-local',
        content: 'local-1',
        updatedAt: DateTime.utc(2026, 10, 26, 14),
      ),
    );
    await meta.touchLocalEdit('c1');

    final key = await keys.getOrCreate();
    final remoteEntry = sample(
      id: 'c1',
      title: 'A-remote',
      content: 'remote-1',
      updatedAt: DateTime.utc(2026, 10, 26, 13),
    );
    final sealed = await SyncEnvelope(crypto).seal(
      entry: remoteEntry,
      localVersion: 2,
      syncKey: key,
    );
    final path = SyncEngine.remotePath('/privatenote/entries', 'c1');
    await webdav.putBytes(path, sealed);

    now = DateTime.utc(2026, 10, 26, 15);
    final report = await engine.synchronize(credentials: creds);
    expect(report.hasConflicts, isTrue);
    final conflictMeta = await meta.getByEntryId('c1');
    expect(conflictMeta?.conflictFlag, isTrue);
    expect(conflictMeta?.pendingRemoteJson, isNotNull);
    expect((await entries.getById('c1'))?.title, 'A-local');
  });

  test('tampered remote blob surfaces CryptoTamperException', () async {
    await entries.create(
      sample(
        id: 't1',
        title: 'T',
        content: 'body',
        updatedAt: DateTime.utc(2026, 10, 26, 9),
      ),
    );
    await meta.upsert(const SyncMeta(entryId: 't1', localVersion: 1));
    await engine.synchronize(credentials: creds);

    final path = SyncEngine.remotePath('/privatenote/entries', 't1');
    final blob = await webdav.getBytes(path);
    final map = jsonDecode(utf8.decode(blob)) as Map<String, dynamic>;
    final raw = base64Decode(map['ciphertext_b64'] as String);
    raw[raw.length ~/ 2] ^= 0x5a;
    map['ciphertext_b64'] = base64Encode(raw);
    await webdav.putBytes(
      path,
      Uint8List.fromList(utf8.encode(jsonEncode(map))),
    );

    await entries.delete('t1');
    await meta.upsert(
      SyncMeta(
        entryId: 't1',
        localVersion: 0,
        lastSyncAt: DateTime.utc(2026, 1, 1),
        remoteEtag: '"old"',
      ),
    );

    final report = await engine.synchronize(credentials: creds);
    expect(report.error, isNotNull);
    expect(report.error!.toLowerCase(), contains('tamper'));
  });

  test('SyncConflictPolicy both-changed returns conflict', () {
    const policy = SyncConflictPolicy();
    final last = DateTime.utc(2026, 10, 1);
    final decision = policy.decide(
      local: sample(
        id: 'x',
        title: 'L',
        content: 'l',
        updatedAt: DateTime.utc(2026, 10, 2),
      ),
      remote: sample(
        id: 'x',
        title: 'R',
        content: 'r',
        updatedAt: DateTime.utc(2026, 10, 3),
      ),
      meta: SyncMeta(
        entryId: 'x',
        localVersion: 2,
        lastSyncAt: last,
        remoteEtag: '"a"',
      ),
      remoteEtag: '"b"',
    );
    expect(decision, SyncConflictDecision.conflict);
  });
}
