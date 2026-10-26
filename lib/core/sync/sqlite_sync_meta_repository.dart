import 'package:sqlite3/sqlite3.dart';

import '../../foundation/db/encrypted_database.dart';
import '../../foundation/db/sync_meta_schema.dart';
import 'sync_meta.dart';
import 'sync_meta_repository.dart';

class SqliteSyncMetaRepository implements SyncMetaRepository {
  SqliteSyncMetaRepository(this._db) {
    SyncMetaSchema.migrate(_db.connection);
  }

  final EncryptedDatabase _db;

  @override
  Future<SyncMeta?> getByEntryId(String entryId) async {
    final rows = _db.connection.select(
      'SELECT * FROM ${SyncMetaSchema.table} WHERE entry_id = ?',
      [entryId],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<SyncMeta>> listAll() async {
    final rows = _db.connection.select(
      'SELECT * FROM ${SyncMetaSchema.table}',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<SyncMeta>> listConflicts() async {
    final rows = _db.connection.select(
      'SELECT * FROM ${SyncMetaSchema.table} WHERE conflict_flag = 1',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsert(SyncMeta meta) async {
    _db.connection.execute(
      '''
INSERT INTO ${SyncMetaSchema.table}
  (entry_id, last_sync_at, remote_etag, local_version, conflict_flag, pending_remote_json)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(entry_id) DO UPDATE SET
  last_sync_at = excluded.last_sync_at,
  remote_etag = excluded.remote_etag,
  local_version = excluded.local_version,
  conflict_flag = excluded.conflict_flag,
  pending_remote_json = excluded.pending_remote_json
''',
      [
        meta.entryId,
        meta.lastSyncAt?.toUtc().millisecondsSinceEpoch,
        meta.remoteEtag,
        meta.localVersion,
        meta.conflictFlag ? 1 : 0,
        meta.pendingRemoteJson,
      ],
    );
  }

  @override
  Future<void> delete(String entryId) async {
    _db.connection.execute(
      'DELETE FROM ${SyncMetaSchema.table} WHERE entry_id = ?',
      [entryId],
    );
  }

  @override
  Future<SyncMeta> touchLocalEdit(String entryId) async {
    final existing = await getByEntryId(entryId);
    if (existing == null) {
      final created = SyncMeta(entryId: entryId, localVersion: 1);
      await upsert(created);
      return created;
    }
    final next = existing.copyWith(localVersion: existing.localVersion + 1);
    await upsert(next);
    return next;
  }

  SyncMeta _fromRow(Row row) {
    final last = row['last_sync_at'] as int?;
    return SyncMeta(
      entryId: row['entry_id'] as String,
      lastSyncAt: last == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(last, isUtc: true),
      remoteEtag: row['remote_etag'] as String?,
      localVersion: row['local_version'] as int,
      conflictFlag: (row['conflict_flag'] as int) == 1,
      pendingRemoteJson: row['pending_remote_json'] as String?,
    );
  }
}
