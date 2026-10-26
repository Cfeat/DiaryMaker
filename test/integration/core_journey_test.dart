import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/app_lock/app_lock_service.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/sqlite_entry_repository.dart';
import 'package:private_note/core/sync/sqlite_sync_meta_repository.dart';
import 'package:private_note/core/sync/sync_credentials_store.dart';
import 'package:private_note/core/sync/sync_engine.dart';
import 'package:private_note/core/sync/sync_envelope.dart';
import 'package:private_note/core/sync/sync_key_manager.dart';
import 'package:private_note/core/sync/sync_meta.dart';
import 'package:private_note/foundation/crypto/crypto_service.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/crypto/pin_hasher.dart';
import 'package:private_note/foundation/db/encrypted_database.dart';
import 'package:private_note/foundation/platform/biometric_auth.dart';
import 'package:private_note/foundation/webdav/memory_webdav_client.dart';

/// F2: full journey on host (Windows) with real AES-GCM + encrypted SQLite.
/// Mock WebDAV only; crypto and DB cipher are not mocked.
void main() {
  test('journey: unlock → write → sync → wipe → restore → unlock', () async {
    const pin = '2468';
    const secretTitle = 'JourneyTitle_ZX9Q';
    const secretBody = 'JourneyBody_PLAINTEXT_MARKER_7f3a';
    final entryId = 'journey-entry-1';

    // --- start / unlock ---
    final lockStorage = InMemorySecureStoragePort();
    final lock = AppLockService(
      storage: lockStorage,
      biometricAuth: const NoOpBiometricAuth(),
      biometricsEnabledByHost: false,
      pinHasher: PinHasher(iterations: PinHasher.testIterations),
    );
    await lock.initialize();
    expect(lock.state.phase, AppLockPhase.needsSetup);
    await lock.setupPin(pin);
    expect(lock.state.phase, AppLockPhase.unlocked);

    // --- write + save (encrypted local DB) ---
    final dbKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 3));
    final db = await EncryptedDatabase.openEphemeral(key: dbKey);
    addTearDown(db.close);
    final repo = SqliteEntryRepository(db);
    final syncMeta = SqliteSyncMetaRepository(db);
    final now = DateTime.utc(2026, 10, 26, 18);
    await repo.create(
      Entry(
        id: entryId,
        title: secretTitle,
        content: secretBody,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await syncMeta.upsert(SyncMeta(entryId: entryId, localVersion: 1));

    // --- sync (Mock WebDAV + real CryptoService) ---
    final secure = InMemorySecureStoragePort();
    final syncKeys = SyncKeyManager(secure);
    final webdav = MemoryWebDavClient();
    final crypto = CryptoService();
    final engine = SyncEngine(
      entries: repo,
      syncMeta: syncMeta,
      envelope: SyncEnvelope(crypto),
      syncKeys: syncKeys,
      clientFactory: (_) => webdav,
      clock: () => DateTime.utc(2026, 10, 26, 19),
    );
    const creds = SyncCredentials(
      baseUrl: 'https://webdav.test',
      username: 'user',
      password: 'token',
      remoteRoot: '/privatenote/entries',
    );
    final pushReport = await engine.synchronize(credentials: creds);
    expect(pushReport.error, isNull);
    expect(pushReport.results.single.action, SyncAction.pushed);

    final remotePath = SyncEngine.remotePath('/privatenote/entries', entryId);
    final uploaded = await webdav.getBytes(remotePath);
    final uploadedText = utf8.decode(uploaded);
    expect(uploadedText.contains(secretTitle), isFalse);
    expect(uploadedText.contains(secretBody), isFalse);

    // --- wipe local ---
    await repo.delete(entryId);
    expect(await repo.getById(entryId), isNull);

    // --- restore from WebDAV into a fresh encrypted DB (same sync key) ---
    final db2 = await EncryptedDatabase.openEphemeral(key: dbKey);
    addTearDown(db2.close);
    final repo2 = SqliteEntryRepository(db2);
    final syncMeta2 = SqliteSyncMetaRepository(db2);
    final sharedKey = await syncKeys.read();
    expect(sharedKey, isNotNull);
    final secure2 = InMemorySecureStoragePort();
    final keys2 = SyncKeyManager(secure2);
    await keys2.importKey(sharedKey!);
    final engine2 = SyncEngine(
      entries: repo2,
      syncMeta: syncMeta2,
      envelope: SyncEnvelope(CryptoService()),
      syncKeys: keys2,
      clientFactory: (_) => webdav,
      clock: () => DateTime.utc(2026, 10, 26, 20),
    );
    final pullReport = await engine2.synchronize(credentials: creds);
    expect(pullReport.error, isNull);
    expect(pullReport.results.single.action, SyncAction.pulled);

    final restored = await repo2.getById(entryId);
    expect(restored, isNotNull);
    expect(restored!.title, secretTitle);
    expect(restored.content, secretBody);

    // --- lock / unlock again ---
    lock.lock();
    expect(lock.state.phase, AppLockPhase.locked);
    expect(await lock.unlockWithPin(pin), isTrue);
    expect(lock.state.phase, AppLockPhase.unlocked);
  });
}
