/// Per-entry sync metadata (`DATA_MODEL.md` §3). No diary body fields.
class SyncMeta {
  const SyncMeta({
    required this.entryId,
    required this.localVersion,
    this.lastSyncAt,
    this.remoteEtag,
    this.conflictFlag = false,
    this.pendingRemoteJson,
  });

  final String entryId;
  final DateTime? lastSyncAt;
  final String? remoteEtag;
  final int localVersion;
  final bool conflictFlag;

  /// Encrypted-envelope plaintext JSON of the remote side when in conflict
  /// (held only in local SQLCipher DB for resolve UI — never uploaded as plaintext).
  final String? pendingRemoteJson;

  SyncMeta copyWith({
    String? entryId,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    String? remoteEtag,
    bool clearRemoteEtag = false,
    int? localVersion,
    bool? conflictFlag,
    String? pendingRemoteJson,
    bool clearPendingRemote = false,
  }) {
    return SyncMeta(
      entryId: entryId ?? this.entryId,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      remoteEtag: clearRemoteEtag ? null : (remoteEtag ?? this.remoteEtag),
      localVersion: localVersion ?? this.localVersion,
      conflictFlag: conflictFlag ?? this.conflictFlag,
      pendingRemoteJson: clearPendingRemote
          ? null
          : (pendingRemoteJson ?? this.pendingRemoteJson),
    );
  }
}
