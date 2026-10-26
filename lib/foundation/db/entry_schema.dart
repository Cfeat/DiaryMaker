import 'package:sqlite3/sqlite3.dart';

/// Applies the Entry schema (and FTS5 when the build supports it).
class EntrySchema {
  EntrySchema._();

  static const entriesTable = 'entries';
  static const ftsTable = 'entries_fts';

  /// Returns whether FTS5 virtual tables can be created.
  static bool fts5Available(Database db) {
    try {
      db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS _fts5_probe USING fts5(x);',
      );
      db.execute('DROP TABLE IF EXISTS _fts5_probe;');
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool migrate(Database db) {
    db.execute('''
CREATE TABLE IF NOT EXISTS $entriesTable (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  mood TEXT,
  tags_json TEXT NOT NULL DEFAULT '[]',
  attachments_json TEXT NOT NULL DEFAULT '[]'
);
''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_entries_created_at '
      'ON $entriesTable(created_at);',
    );

    final fts = fts5Available(db);
    if (fts) {
      db.execute('''
CREATE VIRTUAL TABLE IF NOT EXISTS $ftsTable USING fts5(
  id UNINDEXED,
  title,
  content
);
''');
    }
    return fts;
  }
}
