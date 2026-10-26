import '../entry/entry.dart';
import 'sync_meta.dart';

enum SyncConflictDecision { push, pull, conflict, skip }

/// Conflict rules for Phase D v1 — no automatic merge.
///
/// Local changed: [Entry.updatedAt] is after [SyncMeta.lastSyncAt].
/// Remote changed: ETag differs from [SyncMeta.remoteEtag], or remote
/// [Entry.updatedAt] is after [SyncMeta.lastSyncAt].
/// Both → [SyncConflictDecision.conflict].
class SyncConflictPolicy {
  const SyncConflictPolicy();

  SyncConflictDecision decide({
    required Entry? local,
    required Entry? remote,
    required SyncMeta meta,
    required String? remoteEtag,
  }) {
    if (local == null && remote == null) {
      return SyncConflictDecision.skip;
    }
    if (local == null) return SyncConflictDecision.pull;
    if (remote == null) return SyncConflictDecision.push;

    final lastSync = meta.lastSyncAt;
    if (lastSync == null) {
      // Same device never completed sync for this id, but remote exists.
      if (_sameLogicalContent(local, remote)) {
        return SyncConflictDecision.skip;
      }
      return SyncConflictDecision.conflict;
    }

    final localChanged = local.updatedAt.isAfter(lastSync);
    final etagChanged = meta.remoteEtag != null &&
        remoteEtag != null &&
        meta.remoteEtag != remoteEtag;
    final remoteChanged =
        etagChanged || remote.updatedAt.isAfter(lastSync);

    if (localChanged && remoteChanged) {
      return SyncConflictDecision.conflict;
    }
    if (remoteChanged) return SyncConflictDecision.pull;
    if (localChanged) return SyncConflictDecision.push;
    return SyncConflictDecision.skip;
  }

  static bool _sameLogicalContent(Entry a, Entry b) {
    return a.id == b.id &&
        a.title == b.title &&
        a.content == b.content &&
        a.updatedAt.toUtc() == b.updatedAt.toUtc();
  }
}
