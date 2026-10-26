import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_lock/app_lock_service.dart';
import '../core/entry/entry.dart';
import '../core/entry/entry_repository.dart';
import '../core/sync/sync_credentials_store.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_meta.dart';
import '../core/sync/sync_meta_repository.dart';
import '../foundation/platform/app_host.dart';
import '../foundation/platform/biometric_auth.dart';
import '../foundation/platform/screen_protection.dart';

/// Overridden in [main] / tests after bootstrap.
final appHostProvider = Provider<AppHost>((ref) {
  throw UnimplementedError('appHostProvider must be overridden');
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  throw UnimplementedError('entryRepositoryProvider must be overridden');
});

final syncMetaRepositoryProvider = Provider<SyncMetaRepository>((ref) {
  throw UnimplementedError('syncMetaRepositoryProvider must be overridden');
});

final syncCredentialsStoreProvider = Provider<SyncCredentialsStore>((ref) {
  throw UnimplementedError('syncCredentialsStoreProvider must be overridden');
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  throw UnimplementedError('syncEngineProvider must be overridden');
});

final appLockServiceProvider = Provider<AppLockService>((ref) {
  throw UnimplementedError('appLockServiceProvider must be overridden');
});

final biometricAuthProvider = Provider<BiometricAuth>((ref) {
  throw UnimplementedError('biometricAuthProvider must be overridden');
});

final screenProtectionProvider = Provider<ScreenProtection>((ref) {
  throw UnimplementedError('screenProtectionProvider must be overridden');
});

/// Reactive view of [AppLockService.state].
final appLockStateProvider =
    StateNotifierProvider<AppLockStateNotifier, AppLockState>((ref) {
  final service = ref.watch(appLockServiceProvider);
  return AppLockStateNotifier(service);
});

class AppLockStateNotifier extends StateNotifier<AppLockState> {
  AppLockStateNotifier(this._service) : super(_service.state) {
    _service.addListener(_onChange);
  }

  final AppLockService _service;

  void _onChange(AppLockState next) => state = next;

  @override
  void dispose() {
    _service.removeListener(_onChange);
    super.dispose();
  }

  Future<void> setupPin(String pin) => _service.setupPin(pin);

  Future<bool> unlockWithPin(String pin) => _service.unlockWithPin(pin);

  Future<bool> unlockWithBiometrics() => _service.unlockWithBiometrics();

  Future<void> onAppResumed() => _service.onAppResumed();

  void lock() => _service.lock();
}

final timelineEntriesProvider =
    AsyncNotifierProvider<TimelineEntriesNotifier, List<Entry>>(
  TimelineEntriesNotifier.new,
);

class TimelineEntriesNotifier extends AsyncNotifier<List<Entry>> {
  @override
  Future<List<Entry>> build() {
    return ref.read(entryRepositoryProvider).listOrderedByUpdatedAtDesc();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(entryRepositoryProvider).listOrderedByUpdatedAtDesc(),
    );
  }
}

final syncConflictsProvider =
    FutureProvider<List<SyncMeta>>((ref) async {
  return ref.watch(syncMetaRepositoryProvider).listConflicts();
});
