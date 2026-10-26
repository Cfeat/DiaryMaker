import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/memory_entry_repository.dart';
import 'package:private_note/core/sync/memory_sync_meta_repository.dart';
import 'package:private_note/core/sync/sync_credentials_store.dart';
import 'package:private_note/core/sync/sync_engine.dart';
import 'package:private_note/core/sync/sync_envelope.dart';
import 'package:private_note/core/sync/sync_key_manager.dart';
import 'package:private_note/core/sync/sync_meta.dart';
import 'package:private_note/foundation/crypto/crypto_service.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/webdav/memory_webdav_client.dart';

/// Unit-level SyncEngine API coverage (real CryptoService).
void main() {
  late MemoryEntryRepository entries;
  late MemorySyncMetaRepository meta;
  late MemoryWebDavClient webdav;
  late SyncEngine engine;
  const creds = SyncCredentials(
    baseUrl: 'https://example.test/dav',
    username: 'u',
    password: 'p',
    remoteRoot: '/privatenote/entries',
  );

  Entry sample(String id, String title, DateTime at) => Entry(
        id: id,
        title: title,
        content: 'body-$title',
        createdAt: at,
        updatedAt: at,
      );

  setUp(() {
    entries = MemoryEntryRepository();
    meta = MemorySyncMetaRepository();
    webdav = MemoryWebDavClient();
    final storage = InMemorySecureStoragePort();
    engine = SyncEngine(
      entries: entries,
      syncMeta: meta,
      envelope: SyncEnvelope(CryptoService()),
      syncKeys: SyncKeyManager(storage),
      clientFactory: (_) => webdav,
      clock: () => DateTime.utc(2026, 10, 26, 12),
    );
  });

  group('synchronize', () {
    test('normal — pushes local-only entry', () async {
      await entries.create(
        sample('s1', 'One', DateTime.utc(2026, 10, 26, 10)),
      );
      await meta.upsert(const SyncMeta(entryId: 's1', localVersion: 1));
      final report = await engine.synchronize(credentials: creds);
      expect(report.error, isNull);
      expect(report.results.single.action, SyncAction.pushed);
      expect(await webdav.exists('/privatenote/entries/s1.pn1'), isTrue);
    });

    test('boundary — empty credentials returns error without upload', () async {
      await entries.create(
        sample('s2', 'Two', DateTime.utc(2026, 10, 26, 10)),
      );
      final report = await engine.synchronize(
        credentials: const SyncCredentials(
          baseUrl: '',
          username: '',
          password: '',
        ),
      );
      expect(report.error, isNotNull);
      expect(webdav.debugFiles, isEmpty);
    });

    test('exception path — identical local/remote after sync is skip', () async {
      await entries.create(
        sample('s3', 'Same', DateTime.utc(2026, 10, 26, 10)),
      );
      await meta.upsert(const SyncMeta(entryId: 's3', localVersion: 1));
      await engine.synchronize(credentials: creds);
      final again = await engine.synchronize(credentials: creds);
      expect(again.results.single.action, SyncAction.skipped);
    });
  });

  group('resolveKeepLocal', () {
    test('normal — uploads local and clears conflict', () async {
      final t = DateTime.utc(2026, 10, 26, 10);
      await entries.create(sample('r1', 'LocalWin', t));
      await meta.upsert(
        SyncMeta(
          entryId: 'r1',
          localVersion: 2,
          conflictFlag: true,
          pendingRemoteJson: jsonEncode({
            'entry': SyncEngine.entryToJson(sample('r1', 'Remote', t)),
            'local_version': 9,
            'etag': '"old"',
          }),
        ),
      );
      await engine.resolveKeepLocal(entryId: 'r1', credentials: creds);
      final m = await meta.getByEntryId('r1');
      expect(m?.conflictFlag, isFalse);
      expect(m?.pendingRemoteJson, isNull);
      expect(await webdav.exists('/privatenote/entries/r1.pn1'), isTrue);
    });

    test('boundary — works when SyncMeta row was missing', () async {
      await entries.create(
        sample('r2', 'NoMeta', DateTime.utc(2026, 10, 26, 10)),
      );
      await engine.resolveKeepLocal(entryId: 'r2', credentials: creds);
      expect(await meta.getByEntryId('r2'), isNotNull);
    });

    test('exception — missing local entry throws', () async {
      expect(
        () => engine.resolveKeepLocal(entryId: 'missing', credentials: creds),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('resolveKeepRemote', () {
    test('normal — applies pending remote and clears flag', () async {
      final t = DateTime.utc(2026, 10, 26, 10);
      await entries.create(sample('k1', 'Local', t));
      final remote = sample('k1', 'RemoteKept', t.add(const Duration(hours: 1)));
      await meta.upsert(
        SyncMeta(
          entryId: 'k1',
          localVersion: 1,
          conflictFlag: true,
          pendingRemoteJson: jsonEncode({
            'entry': SyncEngine.entryToJson(remote),
            'local_version': 3,
            'etag': '"r"',
          }),
        ),
      );
      await engine.resolveKeepRemote(entryId: 'k1');
      expect((await entries.getById('k1'))?.title, 'RemoteKept');
      expect((await meta.getByEntryId('k1'))?.conflictFlag, isFalse);
    });

    test('boundary — creates entry when local was deleted', () async {
      final remote = sample('k2', 'OnlyRemote', DateTime.utc(2026, 10, 26));
      await meta.upsert(
        SyncMeta(
          entryId: 'k2',
          localVersion: 1,
          conflictFlag: true,
          pendingRemoteJson: jsonEncode({
            'entry': SyncEngine.entryToJson(remote),
            'local_version': 1,
            'etag': '"x"',
          }),
        ),
      );
      await engine.resolveKeepRemote(entryId: 'k2');
      expect(await entries.getById('k2'), isNotNull);
    });

    test('exception — no pending remote throws', () async {
      await meta.upsert(
        const SyncMeta(entryId: 'k3', localVersion: 1, conflictFlag: true),
      );
      expect(
        () => engine.resolveKeepRemote(entryId: 'k3'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
