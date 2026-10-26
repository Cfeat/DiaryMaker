import 'dart:typed_data';

/// Formats a raw 32-byte key for SQLCipher / sqlite3mc `PRAGMA key`.
///
/// Uses the hex blob form so the key is not treated as a passphrase string.
String sqlcipherKeyPragma(Uint8List key) {
  if (key.isEmpty) {
    throw ArgumentError('Encryption key must not be empty');
  }
  final hex = StringBuffer();
  for (final b in key) {
    hex.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return "PRAGMA key = \"x'$hex'\"";
}

String escapeSqlString(String source) => source.replaceAll("'", "''");
