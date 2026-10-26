import 'sync_meta.dart';
import 'sync_meta_repository.dart';

class MemorySyncMetaRepository implements SyncMetaRepository {
  final Map<String, SyncMeta> _rows = {};

  @override
  Future<SyncMeta?> getByEntryId(String entryId) async => _rows[entryId];

  @override
  Future<List<SyncMeta>> listAll() async => _rows.values.toList();

  @override
  Future<List<SyncMeta>> listConflicts() async =>
      _rows.values.where((m) => m.conflictFlag).toList();

  @override
  Future<void> upsert(SyncMeta meta) async {
    _rows[meta.entryId] = meta;
  }

  @override
  Future<void> delete(String entryId) async {
    _rows.remove(entryId);
  }

  @override
  Future<SyncMeta> touchLocalEdit(String entryId) async {
    final existing = _rows[entryId];
    if (existing == null) {
      final created = SyncMeta(entryId: entryId, localVersion: 1);
      _rows[entryId] = created;
      return created;
    }
    final next = existing.copyWith(localVersion: existing.localVersion + 1);
    _rows[entryId] = next;
    return next;
  }
}
