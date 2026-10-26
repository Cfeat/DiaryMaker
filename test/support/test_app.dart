import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/app/private_note_app.dart';
import 'package:private_note/app/providers.dart';
import 'package:private_note/core/app_lock/app_lock_service.dart';
import 'package:private_note/core/entry/entry_repository.dart';
import 'package:private_note/core/entry/memory_entry_repository.dart';
import 'package:private_note/core/sync/memory_sync_meta_repository.dart';
import 'package:private_note/core/sync/sync_credentials_store.dart';
import 'package:private_note/core/sync/sync_engine.dart';
import 'package:private_note/core/sync/sync_envelope.dart';
import 'package:private_note/core/sync/sync_key_manager.dart';
import 'package:private_note/foundation/crypto/crypto_service.dart';
import 'package:private_note/foundation/crypto/in_memory_secure_storage_port.dart';
import 'package:private_note/foundation/crypto/pin_hasher.dart';
import 'package:private_note/foundation/platform/biometric_auth.dart';
import 'package:private_note/foundation/platform/dart_io_app_host.dart';
import 'package:private_note/foundation/platform/screen_protection.dart';
import 'package:private_note/foundation/webdav/memory_webdav_client.dart';

class TestHarness {
  TestHarness({
    FakeAppHost? host,
    EntryRepository? repository,
  })  : host = host ??
            const FakeAppHost(
              usesDesktopShell: false,
              usesMobileShell: true,
              supportsBiometrics: false,
            ),
        repository = repository ?? MemoryEntryRepository() {
    storage = InMemorySecureStoragePort();
    biometric = const NoOpBiometricAuth();
    screen = const NoOpScreenProtection();
    lockService = AppLockService(
      storage: storage,
      biometricAuth: biometric,
      biometricsEnabledByHost: this.host.supportsBiometrics,
      pinHasher: PinHasher(iterations: PinHasher.testIterations),
    );
    syncMeta = MemorySyncMetaRepository();
    credentialsStore = SyncCredentialsStore(storage);
    syncKeys = SyncKeyManager(storage);
    webdav = MemoryWebDavClient();
    syncEngine = SyncEngine(
      entries: this.repository,
      syncMeta: syncMeta,
      envelope: SyncEnvelope(CryptoService()),
      syncKeys: syncKeys,
      clientFactory: (_) => webdav,
    );
  }

  final FakeAppHost host;
  final EntryRepository repository;
  late final InMemorySecureStoragePort storage;
  late final BiometricAuth biometric;
  late final ScreenProtection screen;
  late final AppLockService lockService;
  late final MemorySyncMetaRepository syncMeta;
  late final SyncCredentialsStore credentialsStore;
  late final SyncKeyManager syncKeys;
  late final MemoryWebDavClient webdav;
  late final SyncEngine syncEngine;

  Future<void> init({bool unlock = false, String pin = '1234'}) async {
    if (unlock) {
      await lockService.setupPin(pin);
    } else {
      await lockService.initialize();
    }
  }

  List<Override> get overrides => [
        appHostProvider.overrideWithValue(host),
        entryRepositoryProvider.overrideWithValue(repository),
        syncMetaRepositoryProvider.overrideWithValue(syncMeta),
        syncCredentialsStoreProvider.overrideWithValue(credentialsStore),
        syncEngineProvider.overrideWithValue(syncEngine),
        appLockServiceProvider.overrideWithValue(lockService),
        biometricAuthProvider.overrideWithValue(biometric),
        screenProtectionProvider.overrideWithValue(screen),
      ];

  Widget app() => ProviderScope(
        overrides: overrides,
        child: const PrivateNoteApp(),
      );
}

Future<TestHarness> pumpPrivateNote(
  WidgetTester tester, {
  FakeAppHost? host,
  EntryRepository? repository,
  bool unlocked = false,
  String pin = '1234',
}) async {
  final harness = TestHarness(host: host, repository: repository);
  await harness.init(unlock: unlocked, pin: pin);
  await tester.pumpWidget(harness.app());
  // Avoid pumpAndSettle — AsyncLoading indicators / focus can run forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return harness;
}
