import 'entry.dart';
import 'entry_repository.dart';

/// In-memory [EntryRepository] for widget tests and previews.
class MemoryEntryRepository implements EntryRepository {
  final Map<String, Entry> _entries = {};

  @override
  Future<Entry> create(Entry entry) async {
    if (entry.id.isEmpty) {
      throw EntryValidationException('id must not be empty');
    }
    if (_entries.containsKey(entry.id)) {
      throw EntryValidationException('Entry id already exists: ${entry.id}');
    }
    _entries[entry.id] = entry;
    return entry;
  }

  @override
  Future<Entry?> getById(String id) async => _entries[id];

  @override
  Future<Entry> update(Entry entry) async {
    if (!_entries.containsKey(entry.id)) {
      throw EntryNotFoundException(entry.id);
    }
    _entries[entry.id] = entry;
    return entry;
  }

  @override
  Future<void> delete(String id) async {
    if (!_entries.containsKey(id)) {
      throw EntryNotFoundException(id);
    }
    _entries.remove(id);
  }

  @override
  Future<List<Entry>> findByCreatedAtRange({
    required DateTime startInclusive,
    required DateTime endInclusive,
  }) async {
    return _entries.values
        .where(
          (e) =>
              !e.createdAt.isBefore(startInclusive) &&
              !e.createdAt.isAfter(endInclusive),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<Entry>> listOrderedByUpdatedAtDesc() async {
    final list = _entries.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<List<Entry>> search({required String query}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      throw EntryValidationException('search query must not be empty');
    }
    return _entries.values
        .where(
          (e) =>
              e.title.toLowerCase().contains(q) ||
              e.content.toLowerCase().contains(q),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
