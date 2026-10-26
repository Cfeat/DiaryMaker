import 'dart:typed_data';

import 'package:webdav_plus/webdav_plus.dart';

import 'webdav_client_port.dart';

/// Production WebDAV via `package:webdav_plus`.
class WebdavPlusClient implements WebDavClientPort {
  WebdavPlusClient({
    required String baseUrl,
    required String username,
    required String password,
  }) : _client = WebdavClient.withCredentials(
          username,
          password,
          baseUrl: baseUrl,
        );

  final WebdavClient _client;

  void shutdown() => _client.shutdown();

  @override
  Future<void> ensureCollection(String path) async {
    try {
      await _client.createDirectory(path);
    } catch (_) {
      // May already exist.
    }
  }

  @override
  Future<void> putBytes(String path, Uint8List bytes) async {
    await _client.put(path, bytes);
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    final data = await _client.get(path);
    return Uint8List.fromList(data);
  }

  @override
  Future<bool> exists(String path) async {
    try {
      return await _client.exists(path);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> delete(String path) async {
    await _client.delete(path);
  }

  @override
  Future<List<WebDavRemoteItem>> listFiles(String path) async {
    final resources = await _client.list(path);
    return resources
        .where((r) => !r.isDirectory)
        .map(
          (r) => WebDavRemoteItem(
            path: r.path,
            name: r.name,
            etag: r.etag,
          ),
        )
        .toList();
  }

  @override
  Future<String?> readEtag(String path) async {
    try {
      final resources = await _client.list(path);
      if (resources.isEmpty) return null;
      return resources.first.etag;
    } catch (_) {
      return null;
    }
  }
}
