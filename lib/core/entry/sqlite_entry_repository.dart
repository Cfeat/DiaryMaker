import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../foundation/db/encrypted_database.dart';
import '../../foundation/db/entry_schema.dart';
import 'entry.dart';
import 'entry_repository.dart';

/// SQLCipher / sqlite3mc-backed [EntryRepository].
class SqliteEntryRepository implements EntryRepository {
  SqliteEntryRepository(this._db) {
    _ftsEnabled = EntrySchema.migrate(_db.connection);
  }

  final EncryptedDatabase _db;
  late final bool _ftsEnabled;

  Database get _conn => _db.connection;

  bool get usesFts5 => _ftsEnabled;

  @override
  Future<Entry> create(Entry entry) async {
    _validate(entry);
    final existing = _conn.select(
      'SELECT id FROM ${EntrySchema.entriesTable} WHERE id = ?',
      [entry.id],
    );
    if (existing.isNotEmpty) {
      throw EntryValidationException('Entry id already exists: ${entry.id}');
    }

    _conn.execute(
      '''
INSERT INTO ${EntrySchema.entriesTable}
  (id, title, content, created_at, updated_at, mood, tags_json, attachments_json)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        entry.id,
        entry.title,
        entry.content,
        entry.createdAt.toUtc().millisecondsSinceEpoch,
        entry.updatedAt.toUtc().millisecondsSinceEpoch,
        entry.mood,
        jsonEncode(entry.tags),
        jsonEncode(entry.attachments.map((a) => a.toJson()).toList()),
      ],
    );
    _upsertFts(entry);
    return entry;
  }

  @override
  Future<Entry?> getById(String id) async {
    if (id.isEmpty) {
      throw EntryValidationException('id must not be empty');
    }
    final rows = _conn.select(
      'SELECT * FROM ${EntrySchema.entriesTable} WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<Entry> update(Entry entry) async {
    _validate(entry);
    final existing = await getById(entry.id);
    if (existing == null) {
      throw EntryNotFoundException(entry.id);
    }

    _conn.execute(
      '''
UPDATE ${EntrySchema.entriesTable}
SET title = ?, content = ?, created_at = ?, updated_at = ?,
    mood = ?, tags_json = ?, attachments_json = ?
WHERE id = ?
''',
      [
        entry.title,
        entry.content,
        entry.createdAt.toUtc().millisecondsSinceEpoch,
        entry.updatedAt.toUtc().millisecondsSinceEpoch,
        entry.mood,
        jsonEncode(entry.tags),
        jsonEncode(entry.attachments.map((a) => a.toJson()).toList()),
        entry.id,
      ],
    );
    _upsertFts(entry);
    return entry;
  }

  @override
  Future<void> delete(String id) async {
    if (id.isEmpty) {
      throw EntryValidationException('id must not be empty');
    }
    final existing = await getById(id);
    if (existing == null) {
      throw EntryNotFoundException(id);
    }
    _conn.execute(
      'DELETE FROM ${EntrySchema.entriesTable} WHERE id = ?',
      [id],
    );
    if (_ftsEnabled) {
      _conn.execute(
        'DELETE FROM ${EntrySchema.ftsTable} WHERE id = ?',
        [id],
      );
    }
  }

  @override
  Future<List<Entry>> findByCreatedAtRange({
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    if (endInclusive.isBefore(startInclusive)) {
      throw EntryValidationException(
        'endInclusive must be >= startInclusive',
      );
    }
    final start = startInclusive.toUtc().millisecondsSinceEpoch;
    final end = endInclusive.toUtc().millisecondsSinceEpoch;
    final rows = _conn.select(
      '''
SELECT * FROM ${EntrySchema.entriesTable}
WHERE created_at >= ? AND created_at <= ?
ORDER BY created_at ASC
''',
      [start, end],
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Entry>> listOrderedByUpdatedAtDesc() async {
    final rows = _conn.select(
      '''
SELECT * FROM ${EntrySchema.entriesTable}
ORDER BY updated_at DESC
''',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Entry>> search({required String query}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw EntryValidationException('search query must not be empty');
    }

    if (_ftsEnabled) {
      final ftsQuery = _toFtsPrefixQuery(trimmed);
      try {
        final rows = _conn.select(
          '''
SELECT e.* FROM ${EntrySchema.ftsTable} AS f
INNER JOIN ${EntrySchema.entriesTable} AS e ON e.id = f.id
WHERE f MATCH ?
ORDER BY e.created_at DESC
''',
          [ftsQuery],
        );
        return rows.map(_fromRow).toList();
      } catch (_) {
        // Fall through to LIKE if MATCH syntax fails for odd input.
      }
    }

    final like = '%${_escapeLike(trimmed)}%';
    final rows = _conn.select(
      '''
SELECT * FROM ${EntrySchema.entriesTable}
WHERE title LIKE ? ESCAPE '\\' OR content LIKE ? ESCAPE '\\'
ORDER BY created_at DESC
''',
      [like, like],
    );
    return rows.map(_fromRow).toList();
  }

  void _upsertFts(Entry entry) {
    if (!_ftsEnabled) return;
    _conn.execute(
      'DELETE FROM ${EntrySchema.ftsTable} WHERE id = ?',
      [entry.id],
    );
    _conn.execute(
      'INSERT INTO ${EntrySchema.ftsTable}(id, title, content) VALUES (?, ?, ?)',
      [entry.id, entry.title, entry.content],
    );
  }

  void _validate(Entry entry) {
    if (entry.id.isEmpty) {
      throw EntryValidationException('id must not be empty');
    }
  }

  Entry _fromRow(Row row) {
    final tagsRaw = jsonDecode(row['tags_json'] as String) as List<dynamic>;
    final attachmentsRaw =
        jsonDecode(row['attachments_json'] as String) as List<dynamic>;
    return Entry(
      id: row['id'] as String,
      title: row['title'] as String,
      content: row['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
        isUtc: true,
      ),
      mood: row['mood'] as String?,
      tags: tagsRaw.map((e) => e as String).toList(),
      attachments: attachmentsRaw
          .map((e) => EntryAttachment.fromJson(
                Map<String, Object?>.from(e as Map),
              ))
          .toList(),
    );
  }

  static String _escapeLike(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  /// Builds a simple FTS5 prefix query from whitespace-separated tokens.
  static String _toFtsPrefixQuery(String input) {
    final tokens = input
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '"${t.replaceAll('"', '')}"*')
        .toList();
    if (tokens.isEmpty) return '""';
    return tokens.join(' ');
  }
}
