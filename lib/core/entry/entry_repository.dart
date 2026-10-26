import 'entry.dart';

/// CRUD + query API for diary entries (core layer).
abstract class EntryRepository {
  Future<Entry> create(Entry entry);

  Future<Entry?> getById(String id);

  Future<Entry> update(Entry entry);

  Future<void> delete(String id);

  /// Inclusive UTC range range on [Entry.createdAt].
  Future<List<Entry>> findByCreatedAtRange({
    required DateTime startInclusive,
    required DateTime endInclusive,
  });

  /// All entries, newest [Entry.updatedAt] first (timeline default).
  Future<List<Entry>> listOrderedByUpdatedAtDesc();

  /// Fuzzy search over title/content (FTS5 when available, else LIKE fallback).
  Future<List<Entry>> search({required String query});
}

class EntryNotFoundException implements Exception {
  EntryNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'EntryNotFoundException: $id';
}

class EntryValidationException implements Exception {
  EntryValidationException(this.message);

  final String message;

  @override
  String toString() => 'EntryValidationException: $message';
}
