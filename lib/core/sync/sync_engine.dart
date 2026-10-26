import 'dart:convert';
import 'dart:typed_data';

import '../../foundation/webdav/webdav_client_port.dart';
import '../entry/entry.dart';
import '../entry/entry_repository.dart';
import 'sync_conflict_policy.dart';
import 'sync_credentials_store.dart';
import 'sync_envelope.dart';
import 'sync_key_manager.dart';
import 'sync_meta.dart';
import 'sync_meta_repository.dart';

enum SyncAction { pushed, pulled, skipped, conflict }

class SyncEntryResult {
  const SyncEntryResult({
    required this.entryId,
    required this.action,
    this.message,
  });

  final String entryId;
  final SyncAction action;
  final String? message;
}

class SyncReport {
  SyncReport({required this.results, this.error});

  final List<SyncEntryResult> results;
  final String? error;

  bool get hasConflicts =>
      results.any((r) => r.action == SyncAction.conflict);
}

/// Push/pull encrypted envelopes over user WebDAV; no auto-merge on conflict.
class SyncEngine {
  SyncEngine({
    required this.entries,
    required this.syncMeta,
    required this.envelope,
    required this.syncKeys,
    required this.clientFactory,
    SyncConflictPolicy? conflictPolicy,
    DateTime Function()? clock,
  })  : _policy = conflictPolicy ?? const SyncConflictPolicy(),
        _clock = clock ?? DateTime.now;

  final EntryRepository entries;
  final SyncMetaRepository syncMeta;
  final SyncEnvelope envelope;
  final SyncKeyManager syncKeys;
  final WebDavClientPort Function(SyncCredentials credentials) clientFactory;
  final SyncConflictPolicy _policy;
  final DateTime Function() _clock;

  Future<SyncReport> synchronize({
    required SyncCredentials credentials,
  }) async {
    if (!credentials.isConfigured) {
      return SyncReport(results: const [], error: 'WebDAV is not configured');
    }

    final key = await syncKeys.getOrCreate();
    final client = clientFactory(credentials);
    final root = normalizeRoot(credentials.remoteRoot);
    await client.ensureCollection(root);

    final results = <SyncEntryResult>[];
    try {
      final locals = await entries.listOrderedByUpdatedAtDesc();
      final localById = {for (final e in locals) e.id: e};
      final remoteItems = await client.listFiles(root);
      final remoteById = <String, WebDavRemoteItem>{};
      for (final item in remoteItems) {
        final id = idFromFileName(item.name);
        if (id != null) remoteById[id] = item;
      }

      final ids = {...localById.keys, ...remoteById.keys};
      for (final id in ids) {
        results.add(
          await _syncOne(
            entryId: id,
            local: localById[id],
            remoteItem: remoteById[id],
            client: client,
            root: root,
            syncKey: key,
          ),
        );
      }
      return SyncReport(results: results);
    } catch (e) {
      return SyncReport(results: results, error: '$e');
    }
  }

  Future<SyncEntryResult> _syncOne({
    required String entryId,
    required Entry? local,
    required WebDavRemoteItem? remoteItem,
    required WebDavClientPort client,
    required String root,
    required Uint8List syncKey,
  }) async {
    final meta = await syncMeta.getByEntryId(entryId) ??
        SyncMeta(entryId: entryId, localVersion: local == null ? 0 : 1);
    final path = remotePath(root, entryId);

    RemoteEntrySnapshot? remote;
    if (remoteItem != null) {
      final bytes = await client.getBytes(remoteItem.path);
      remote = await envelope.open(fileBytes: bytes, syncKey: syncKey);
    }

    final remoteEtag = remoteItem?.etag ?? await client.readEtag(path);
    final decision = _policy.decide(
      local: local,
      remote: remote?.entry,
      meta: meta,
      remoteEtag: remoteEtag,
    );

    switch (decision) {
      case SyncConflictDecision.push:
        final version = meta.localVersion <= 0 ? 1 : meta.localVersion;
        final sealed = await envelope.seal(
          entry: local!,
          localVersion: version,
          syncKey: syncKey,
        );
        await client.putBytes(path, sealed);
        final etag = await client.readEtag(path);
        await syncMeta.upsert(
          meta.copyWith(
            lastSyncAt: _clock().toUtc(),
            remoteEtag: etag,
            localVersion: version,
            conflictFlag: false,
            clearPendingRemote: true,
          ),
        );
        return SyncEntryResult(entryId: entryId, action: SyncAction.pushed);

      case SyncConflictDecision.pull:
        final incoming = remote!.entry;
        final existing = await entries.getById(entryId);
        if (existing == null) {
          await entries.create(incoming);
        } else {
          await entries.update(incoming);
        }
        await syncMeta.upsert(
          meta.copyWith(
            lastSyncAt: _clock().toUtc(),
            remoteEtag: remoteEtag,
            localVersion: remote.localVersion,
            conflictFlag: false,
            clearPendingRemote: true,
          ),
        );
        return SyncEntryResult(entryId: entryId, action: SyncAction.pulled);

      case SyncConflictDecision.conflict:
        await syncMeta.upsert(
          meta.copyWith(
            conflictFlag: true,
            pendingRemoteJson: jsonEncode({
              'entry': entryToJson(remote!.entry),
              'local_version': remote.localVersion,
              'etag': remoteEtag,
            }),
          ),
        );
        return SyncEntryResult(
          entryId: entryId,
          action: SyncAction.conflict,
          message: 'Local and remote both changed since last sync',
        );

      case SyncConflictDecision.skip:
        return SyncEntryResult(entryId: entryId, action: SyncAction.skipped);
    }
  }

  Future<void> resolveKeepLocal({
    required String entryId,
    required SyncCredentials credentials,
  }) async {
    final local = await entries.getById(entryId);
    if (local == null) {
      throw StateError('missing local entry $entryId');
    }
    final meta = await syncMeta.getByEntryId(entryId) ??
        SyncMeta(entryId: entryId, localVersion: 1);
    final key = await syncKeys.getOrCreate();
    final client = clientFactory(credentials);
    final root = normalizeRoot(credentials.remoteRoot);
    final path = remotePath(root, entryId);
    final nextVersion = meta.localVersion + 1;
    final sealed = await envelope.seal(
      entry: local,
      localVersion: nextVersion,
      syncKey: key,
    );
    await client.putBytes(path, sealed);
    final etag = await client.readEtag(path);
    await syncMeta.upsert(
      meta.copyWith(
        lastSyncAt: _clock().toUtc(),
        remoteEtag: etag,
        localVersion: nextVersion,
        conflictFlag: false,
        clearPendingRemote: true,
      ),
    );
  }

  Future<void> resolveKeepRemote({required String entryId}) async {
    final meta = await syncMeta.getByEntryId(entryId);
    final pending = meta?.pendingRemoteJson;
    if (meta == null || pending == null) {
      throw StateError('no pending remote for $entryId');
    }
    final map = jsonDecode(pending) as Map<String, dynamic>;
    final entryMap = Map<String, Object?>.from(map['entry'] as Map);
    final remote = entryFromJson(entryMap);
    final existing = await entries.getById(entryId);
    if (existing == null) {
      await entries.create(remote);
    } else {
      await entries.update(remote);
    }
    await syncMeta.upsert(
      meta.copyWith(
        lastSyncAt: _clock().toUtc(),
        remoteEtag: map['etag'] as String?,
        localVersion: map['local_version'] as int? ?? meta.localVersion,
        conflictFlag: false,
        clearPendingRemote: true,
      ),
    );
  }

  static String normalizeRoot(String root) {
    var r = root.trim().replaceAll('\\', '/');
    if (!r.startsWith('/')) r = '/$r';
    if (r.endsWith('/')) r = r.substring(0, r.length - 1);
    return r;
  }

  static String remotePath(String root, String entryId) =>
      '$root/$entryId${SyncEnvelope.fileSuffix}';

  static String? idFromFileName(String name) {
    if (!name.endsWith(SyncEnvelope.fileSuffix)) return null;
    return name.substring(0, name.length - SyncEnvelope.fileSuffix.length);
  }

  static Map<String, Object?> entryToJson(Entry e) => {
        'id': e.id,
        'title': e.title,
        'content': e.content,
        'created_at': e.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': e.updatedAt.toUtc().millisecondsSinceEpoch,
        'mood': e.mood,
        'tags': e.tags,
        'attachments': e.attachments.map((a) => a.toJson()).toList(),
      };

  static Entry entryFromJson(Map<String, Object?> json) {
    return Entry(
      id: json['id']! as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['created_at']! as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updated_at']! as int,
        isUtc: true,
      ),
      mood: json['mood'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .map(
            (e) => EntryAttachment.fromJson(
              Map<String, Object?>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}
