import 'dart:io';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../crypto/key_manager.dart';
import 'sqlcipher_key_pragma.dart';

/// Opens / closes an on-disk or in-memory DB encrypted with SQLite3MultipleCiphers.
class EncryptedDatabase {
  EncryptedDatabase._(
    this.connection,
    this.filePath, {
    this._ephemeralDir,
  });

  final Database connection;

  /// Absolute path to the DB file.
  final String? filePath;

  final Directory? _ephemeralDir;

  static const relativeDbPath = 'private_note/sqlcipher.db';

  /// Returns true when the loaded native library exposes cipher pragmas.
  static bool hasCipher(Database database) {
    try {
      return database.select('PRAGMA cipher;').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Opens [file] with [key]. Creates parent directories as needed.
  ///
  /// When [requireCipher] is true (default), throws if SQLite3MultipleCiphers
  /// is not linked (hooks misconfigured).
  static Future<EncryptedDatabase> openFile({
    required File file,
    required Uint8List key,
    bool requireCipher = true,
  }) async {
    await file.parent.create(recursive: true);
    final db = sqlite3.open(file.path);
    return _configure(db, key, filePath: file.path, requireCipher: requireCipher);
  }

  /// Ephemeral **file-backed** encrypted DB for tests.
  ///
  /// SQLite3MultipleCiphers rejects `PRAGMA key` on true in-memory / temp DBs
  /// ("Setting key not supported for in-memory or temporary databases").
  static Future<EncryptedDatabase> openEphemeral({
    required Uint8List key,
    bool requireCipher = true,
  }) async {
    final dir = await Directory.systemTemp.createTemp('private_note_db_');
    final file = File('${dir.path}/ephemeral.db');
    final opened = await openFile(
      file: file,
      key: key,
      requireCipher: requireCipher,
    );
    return EncryptedDatabase._(
      opened.connection,
      opened.filePath,
      ephemeralDir: dir,
    );
  }

  static EncryptedDatabase _configure(
    Database db,
    Uint8List key, {
    required String? filePath,
    required bool requireCipher,
  }) {
    try {
      if (requireCipher && !hasCipher(db)) {
        db.close();
        throw StateError(
          'SQLite3MultipleCiphers is not available. '
          'Ensure pubspec hooks set sqlite3.source: sqlite3mc.',
        );
      }
      db.execute(sqlcipherKeyPragma(key));
      // Verify key accepted: cipher_version or a no-op query after key.
      try {
        db.select('SELECT count(*) AS c FROM sqlite_master;');
      } catch (e) {
        db.close();
        throw DbKeyUnavailableException(
          'Failed to open encrypted database with provided key: $e',
        );
      }
      return EncryptedDatabase._(db, filePath);
    } catch (e) {
      if (e is DbKeyUnavailableException || e is StateError) rethrow;
      db.close();
      rethrow;
    }
  }

  void close() {
    connection.close();
    final dir = _ephemeralDir;
    if (dir != null && dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup of temp test dirs.
      }
    }
  }
}
