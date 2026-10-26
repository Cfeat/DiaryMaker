import 'sync_meta.dart';

abstract class SyncMetaRepository {
  Future<SyncMeta?> getByEntryId(String entryId);

  Future<List<SyncMeta>> listAll();

  Future<List<SyncMeta>> listConflicts();

  Future<void> upsert(SyncMeta meta);

  Future<void> delete(String entryId);

  /// Ensures a row exists; bumps [SyncMeta.localVersion] on local edits.
  Future<SyncMeta> touchLocalEdit(String entryId);
}
