import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'encrypted_database.dart';

/// Resolves the on-disk encrypted DB path under application support.
Future<File> resolveEncryptedDatabaseFile() async {
  final support = await getApplicationSupportDirectory();
  return File(p.join(support.path, EncryptedDatabase.relativeDbPath));
}
