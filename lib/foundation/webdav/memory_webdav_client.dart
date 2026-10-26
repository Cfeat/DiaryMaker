import 'dart:typed_data';

import 'webdav_client_port.dart';

/// In-memory WebDAV stand-in for integration tests.
class MemoryWebDavClient implements WebDavClientPort {
  final Map<String, Uint8List> _files = {};
  final Map<String, String> _etags = {};
  var _etagSeq = 0;

  Map<String, Uint8List> get debugFiles => Map.unmodifiable(_files);

  String _norm(String path) {
    var p = path.replaceAll('\\', '/');
    if (!p.startsWith('/')) p = '/$p';
    if (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  @override
  Future<void> ensureCollection(String path) async {}

  @override
  Future<void> putBytes(String path, Uint8List bytes) async {
    final key = _norm(path);
    _files[key] = Uint8List.fromList(bytes);
    _etagSeq += 1;
    _etags[key] = '"mem-$_etagSeq"';
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    final key = _norm(path);
    final data = _files[key];
    if (data == null) {
      throw WebDavException('Not found: $key');
    }
    return Uint8List.fromList(data);
  }

  @override
  Future<bool> exists(String path) async => _files.containsKey(_norm(path));

  @override
  Future<void> delete(String path) async {
    final key = _norm(path);
    _files.remove(key);
    _etags.remove(key);
  }

  @override
  Future<List<WebDavRemoteItem>> listFiles(String path) async {
    final prefix = _norm(path);
    final base = '$prefix/';
    final items = <WebDavRemoteItem>[];
    for (final entry in _files.entries) {
      if (!entry.key.startsWith(base)) continue;
      final rest = entry.key.substring(base.length);
      if (rest.isEmpty || rest.contains('/')) continue;
      items.add(
        WebDavRemoteItem(
          path: entry.key,
          name: rest,
          etag: _etags[entry.key],
        ),
      );
    }
    return items;
  }

  @override
  Future<String?> readEtag(String path) async => _etags[_norm(path)];
}
