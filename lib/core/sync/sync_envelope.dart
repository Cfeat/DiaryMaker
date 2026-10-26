import 'dart:convert';
import 'dart:typed_data';

import '../../foundation/crypto/crypto_service.dart';
import '../entry/entry.dart';

/// Builds / parses sync wire objects: plaintext index + AES-GCM payload (§2.1).
class SyncEnvelope {
  SyncEnvelope(this._crypto);

  static const formatVersion = 1;
  static const fileSuffix = '.pn1';

  final CryptoService _crypto;

  /// Sensitive fields only — encrypted with [syncKey].
  Map<String, Object?> sensitiveMap(Entry entry) => {
        'title': entry.title,
        'content': entry.content,
        'mood': entry.mood,
        'tags': entry.tags,
        'attachments': entry.attachments.map((a) => a.toJson()).toList(),
        'created_at': entry.createdAt.toUtc().millisecondsSinceEpoch,
      };

  Future<Uint8List> seal({
    required Entry entry,
    required int localVersion,
    required Uint8List syncKey,
  }) async {
    final sensitiveJson = utf8.encode(jsonEncode(sensitiveMap(entry)));
    final cipher = await _crypto.encrypt(
      plaintext: Uint8List.fromList(sensitiveJson),
      key: syncKey,
    );
    final envelope = <String, Object?>{
      'format': formatVersion,
      'id': entry.id,
      'updated_at': entry.updatedAt.toUtc().millisecondsSinceEpoch,
      'local_version': localVersion,
      'ciphertext_b64': base64Encode(cipher),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  Future<RemoteEntrySnapshot> open({
    required Uint8List fileBytes,
    required Uint8List syncKey,
  }) async {
    if (fileBytes.isEmpty) {
      throw CryptoFormatException('sync envelope file is empty');
    }
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(utf8.decode(fileBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw CryptoFormatException('sync envelope is not JSON: $e');
    }
    final id = root['id'] as String?;
    final updatedMs = root['updated_at'] as int?;
    final localVersion = root['local_version'] as int? ?? 0;
    final b64 = root['ciphertext_b64'] as String?;
    if (id == null || updatedMs == null || b64 == null) {
      throw CryptoFormatException('sync envelope missing required fields');
    }
    final cipher = base64Decode(b64);
    final clear = await _crypto.decrypt(
      ciphertext: Uint8List.fromList(cipher),
      key: syncKey,
    );
    final sensitive = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final entry = Entry(
      id: id,
      title: sensitive['title'] as String? ?? '',
      content: sensitive['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        sensitive['created_at'] as int? ?? updatedMs,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs, isUtc: true),
      mood: sensitive['mood'] as String?,
      tags: (sensitive['tags'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      attachments: (sensitive['attachments'] as List<dynamic>? ?? const [])
          .map(
            (e) => EntryAttachment.fromJson(
              Map<String, Object?>.from(e as Map),
            ),
          )
          .toList(),
    );
    return RemoteEntrySnapshot(
      entry: entry,
      localVersion: localVersion,
      envelopeJson: utf8.decode(fileBytes),
    );
  }
}

class RemoteEntrySnapshot {
  const RemoteEntrySnapshot({
    required this.entry,
    required this.localVersion,
    required this.envelopeJson,
  });

  final Entry entry;
  final int localVersion;
  final String envelopeJson;
}
