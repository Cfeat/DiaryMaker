import 'dart:typed_data';

/// Narrow WebDAV port used by sync (foundation). No diary semantics.
abstract class WebDavClientPort {
  Future<void> ensureCollection(String path);

  Future<void> putBytes(String path, Uint8List bytes);

  Future<Uint8List> getBytes(String path);

  Future<bool> exists(String path);

  Future<void> delete(String path);

  /// Lists non-collection children under [path].
  Future<List<WebDavRemoteItem>> listFiles(String path);

  /// Best-effort ETag after PUT/GET; mock may synthesize.
  Future<String?> readEtag(String path);
}

class WebDavRemoteItem {
  const WebDavRemoteItem({
    required this.path,
    required this.name,
    this.etag,
  });

  final String path;
  final String name;
  final String? etag;
}

class WebDavException implements Exception {
  WebDavException(this.message);

  final String message;

  @override
  String toString() => 'WebDavException: $message';
}
