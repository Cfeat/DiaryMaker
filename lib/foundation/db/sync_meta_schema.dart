import 'package:sqlite3/sqlite3.dart';

class SyncMetaSchema {
  SyncMetaSchema._();

  static const table = 'sync_meta';

  static void migrate(Database db) {
    db.execute('''
CREATE TABLE IF NOT EXISTS $table (
  entry_id TEXT PRIMARY KEY NOT NULL,
  last_sync_at INTEGER,
  remote_etag TEXT,
  local_version INTEGER NOT NULL DEFAULT 1,
  conflict_flag INTEGER NOT NULL DEFAULT 0,
  pending_remote_json TEXT
);
''');
  }
}
