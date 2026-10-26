import '../core/app_lock/app_lock_service.dart';
import '../core/entry/entry_repository.dart';
import '../core/entry/sqlite_entry_repository.dart';
import '../core/sync/sqlite_sync_meta_repository.dart';
import '../core/sync/sync_credentials_store.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_envelope.dart';
import '../core/sync/sync_key_manager.dart';
import '../core/sync/sync_meta_repository.dart';
import '../foundation/crypto/crypto_service.dart';
import '../foundation/crypto/key_manager.dart';
import '../foundation/crypto/platform_key_managers.dart';
import '../foundation/crypto/secure_storage_port.dart';
import '../foundation/db/database_paths.dart';
import '../foundation/db/encrypted_database.dart';
import '../foundation/platform/app_host.dart';
import '../foundation/platform/biometric_auth.dart';
import '../foundation/platform/dart_io_app_host.dart';
import '../foundation/platform/local_auth_biometric.dart';
import '../foundation/platform/screen_protection.dart';
import '../foundation/platform/screen_protector_protection.dart';
import '../foundation/webdav/webdav_plus_client.dart';

class AppBootstrap {
  AppBootstrap({
    required this.appHost,
    required this.keyManager,
    required this.secureStorage,
    required this.biometricAuth,
    required this.screenProtection,
    required this.database,
    required this.entryRepository,
    required this.syncMetaRepository,
    required this.syncCredentialsStore,
    required this.syncKeyManager,
    required this.syncEngine,
    required this.appLockService,
  });

  final AppHost appHost;
  final KeyManager keyManager;
  final SecureStoragePort secureStorage;
  final BiometricAuth biometricAuth;
  final ScreenProtection screenProtection;
  final EncryptedDatabase database;
  final EntryRepository entryRepository;
  final SyncMetaRepository syncMetaRepository;
  final SyncCredentialsStore syncCredentialsStore;
  final SyncKeyManager syncKeyManager;
  final SyncEngine syncEngine;
  final AppLockService appLockService;

  static Future<AppBootstrap> production() async {
    final host = const DartIoAppHost();
    final keyManager = createPlatformKeyManager();
    final storage = createPlatformSecureStoragePort();
    final biometric = host.supportsBiometrics
        ? LocalAuthBiometric()
        : const NoOpBiometricAuth();
    final screen = host.supportsScreenProtection
        ? ScreenProtectorProtection()
        : const NoOpScreenProtection();

    if (host.supportsScreenProtection) {
      try {
        await screen.enable();
      } catch (_) {
        // Plugin may be unavailable on desktop embeds; ignore.
      }
    }

    final key = await keyManager.getOrCreateDatabaseKey();
    final dbFile = await resolveEncryptedDatabaseFile();
    final database = await EncryptedDatabase.openFile(file: dbFile, key: key);
    final repo = SqliteEntryRepository(database);
    final syncMeta = SqliteSyncMetaRepository(database);
    final creds = SyncCredentialsStore(storage);
    final syncKeys = SyncKeyManager(storage);
    final crypto = CryptoService();
    final engine = SyncEngine(
      entries: repo,
      syncMeta: syncMeta,
      envelope: SyncEnvelope(crypto),
      syncKeys: syncKeys,
      clientFactory: (c) => WebdavPlusClient(
        baseUrl: c.baseUrl,
        username: c.username,
        password: c.password,
      ),
    );
    final lock = AppLockService(
      storage: storage,
      biometricAuth: biometric,
      biometricsEnabledByHost: host.supportsBiometrics,
    );
    await lock.initialize();

    return AppBootstrap(
      appHost: host,
      keyManager: keyManager,
      secureStorage: storage,
      biometricAuth: biometric,
      screenProtection: screen,
      database: database,
      entryRepository: repo,
      syncMetaRepository: syncMeta,
      syncCredentialsStore: creds,
      syncKeyManager: syncKeys,
      syncEngine: engine,
      appLockService: lock,
    );
  }

  void dispose() {
    database.close();
  }
}
