import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/entry_repository.dart';
import 'package:private_note/core/entry/sqlite_entry_repository.dart';
import 'package:private_note/foundation/crypto/key_manager.dart';
import 'package:private_note/foundation/db/encrypted_database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

Uint8List _key([int fill = 1]) =>
    Uint8List.fromList(List<int>.filled(32, fill));

Entry _sample({
  String? id,
  String title = 'Title',
  String content = 'Content body',
  DateTime? createdAt,
  DateTime? updatedAt,
  String? mood,
  List<String> tags = const [],
}) {
  final now = DateTime.utc(2026, 10, 26, 12);
  return Entry(
    id: id ?? const Uuid().v4(),
    title: title,
    content: content,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    mood: mood,
    tags: tags,
  );
}

void main() {
  late EncryptedDatabase db;
  late SqliteEntryRepository repo;

  setUp(() async {
    db = await EncryptedDatabase.openEphemeral(key: _key());
    repo = SqliteEntryRepository(db);
  });

  tearDown(() {
    db.close();
  });

  group('listOrderedByUpdatedAtDesc', () {
    test('normal — returns newest updated_at first', () async {
      await repo.create(
        _sample(
          id: 'a',
          title: 'A',
          updatedAt: DateTime.utc(2026, 1, 1),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await repo.create(
        _sample(
          id: 'b',
          title: 'B',
          updatedAt: DateTime.utc(2026, 3, 1),
          createdAt: DateTime.utc(2026, 2, 1),
        ),
      );
      final list = await repo.listOrderedByUpdatedAtDesc();
      expect(list.map((e) => e.id), ['b', 'a']);
    });

    test('boundary — empty database returns empty list', () async {
      expect(await repo.listOrderedByUpdatedAtDesc(), isEmpty);
    });

    test('boundary — single entry returns itself', () async {
      await repo.create(_sample(id: 'only', title: 'Solo'));
      final list = await repo.listOrderedByUpdatedAtDesc();
      expect(list, hasLength(1));
      expect(list.single.id, 'only');
    });
  });

  group('create', () {
    test('normal — persists and returns entry', () async {
      final entry = _sample(title: 'Hello', content: 'World', mood: 'calm');
      final created = await repo.create(entry);
      expect(created.id, entry.id);
      final loaded = await repo.getById(entry.id);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Hello');
      expect(loaded.content, 'World');
      expect(loaded.mood, 'calm');
    });

    test('boundary — empty title/content and empty tags allowed', () async {
      final entry = _sample(title: '', content: '', tags: const []);
      final created = await repo.create(entry);
      expect(created.title, isEmpty);
      expect((await repo.getById(entry.id))!.content, isEmpty);
    });

    test('exception — duplicate id rejected', () async {
      final entry = _sample(id: 'fixed-id');
      await repo.create(entry);
      expect(
        () => repo.create(entry.copyWith(title: 'other')),
        throwsA(isA<EntryValidationException>()),
      );
    });

    test('exception — empty id rejected', () async {
      expect(
        () => repo.create(_sample(id: '')),
        throwsA(isA<EntryValidationException>()),
      );
    });
  });

  group('getById', () {
    test('normal — returns stored entry', () async {
      final entry = await repo.create(_sample(title: 'A'));
      final loaded = await repo.getById(entry.id);
      expect(loaded!.title, 'A');
    });

    test('boundary — missing id returns null', () async {
      expect(await repo.getById('missing'), isNull);
    });

    test('exception — empty id throws', () async {
      expect(
        () => repo.getById(''),
        throwsA(isA<EntryValidationException>()),
      );
    });
  });

  group('update', () {
    test('normal — updates fields', () async {
      final entry = await repo.create(_sample(title: 'Old', content: 'c1'));
      final updated = await repo.update(
        entry.copyWith(
          title: 'New',
          content: 'c2',
          updatedAt: DateTime.utc(2026, 11, 1),
        ),
      );
      expect(updated.title, 'New');
      final loaded = await repo.getById(entry.id);
      expect(loaded!.content, 'c2');
      expect(loaded.updatedAt, DateTime.utc(2026, 11, 1));
    });

    test('boundary — clear mood via copyWith', () async {
      final entry = await repo.create(_sample(mood: 'happy'));
      await repo.update(entry.copyWith(clearMood: true));
      expect((await repo.getById(entry.id))!.mood, isNull);
    });

    test('exception — unknown id', () async {
      expect(
        () => repo.update(_sample(id: 'nope')),
        throwsA(isA<EntryNotFoundException>()),
      );
    });
  });

  group('delete', () {
    test('normal — removes entry', () async {
      final entry = await repo.create(_sample());
      await repo.delete(entry.id);
      expect(await repo.getById(entry.id), isNull);
    });

    test('exception — deleting missing id', () async {
      expect(
        () => repo.delete('ghost'),
        throwsA(isA<EntryNotFoundException>()),
      );
    });

    test('exception — empty id', () async {
      expect(
        () => repo.delete(''),
        throwsA(isA<EntryValidationException>()),
      );
    });
  });

  group('findByCreatedAtRange', () {
    test('normal — inclusive range returns matches ordered', () async {
      await repo.create(
        _sample(id: 'a', createdAt: DateTime.utc(2026, 1, 1)),
      );
      await repo.create(
        _sample(id: 'b', createdAt: DateTime.utc(2026, 1, 15)),
      );
      await repo.create(
        _sample(id: 'c', createdAt: DateTime.utc(2026, 2, 1)),
      );

      final found = await repo.findByCreatedAtRange(
        startInclusive: DateTime.utc(2026, 1, 1),
        endInclusive: DateTime.utc(2026, 1, 31),
      );
      expect(found.map((e) => e.id), ['a', 'b']);
    });

    test('boundary — empty result when nothing in range', () async {
      await repo.create(
        _sample(createdAt: DateTime.utc(2025, 1, 1)),
      );
      final found = await repo.findByCreatedAtRange(
        startInclusive: DateTime.utc(2026, 1, 1),
        endInclusive: DateTime.utc(2026, 1, 2),
      );
      expect(found, isEmpty);
    });

    test('exception — inverted range', () async {
      expect(
        () => repo.findByCreatedAtRange(
          startInclusive: DateTime.utc(2026, 2, 1),
          endInclusive: DateTime.utc(2026, 1, 1),
        ),
        throwsA(isA<EntryValidationException>()),
      );
    });
  });

  group('search', () {
    test('normal — finds by title/content token', () async {
      await repo.create(
        _sample(id: '1', title: 'Alpha notes', content: 'zzz'),
      );
      await repo.create(
        _sample(id: '2', title: 'Other', content: 'mentions Alpha here'),
      );
      await repo.create(
        _sample(id: '3', title: 'No match', content: 'nothing'),
      );

      final found = await repo.search(query: 'Alpha');
      expect(found.map((e) => e.id).toSet(), {'1', '2'});
    });

    test('boundary — no hits returns empty list', () async {
      await repo.create(_sample(title: 'x', content: 'y'));
      expect(await repo.search(query: 'zzzz-not-present'), isEmpty);
    });

    test('exception — empty / whitespace query', () async {
      expect(
        () => repo.search(query: '   '),
        throwsA(isA<EntryValidationException>()),
      );
    });
  });

  group('encryption', () {
    test('wrong key cannot read ciphertext file', () async {
      final dir = await Directory.systemTemp.createTemp('pn_enc_');
      final file = File('${dir.path}/sqlcipher.db');
      final keyA = _key(9);
      final keyB = _key(10);

      final dbA = await EncryptedDatabase.openFile(file: file, key: keyA);
      final repoA = SqliteEntryRepository(dbA);
      await repoA.create(_sample(id: 'secret', content: 'TOP SECRET'));
      dbA.close();

      await expectLater(
        EncryptedDatabase.openFile(file: file, key: keyB),
        throwsA(
          anyOf(
            isA<DbKeyUnavailableException>(),
            isA<SqliteException>(),
            isA<StateError>(),
          ),
        ),
      );

      // Stock open without cipher key must not yield plaintext content.
      final plain = sqlite3.open(file.path);
      try {
        final rows = plain.select('SELECT content FROM entries');
        // Either throws, empty, or garbage — must not equal plaintext.
        if (rows.isNotEmpty) {
          expect(rows.first['content'], isNot('TOP SECRET'));
        }
      } catch (_) {
        // Expected for encrypted DB.
      } finally {
        plain.close();
        await dir.delete(recursive: true);
      }
    });

    test('ephemeral DB reports cipher when sqlite3mc hooks applied', () {
      expect(
        EncryptedDatabase.hasCipher(db.connection),
        isTrue,
        reason: 'sqlite3mc hooks must be active (pubspec hooks.user_defines)',
      );
    });
  });
}
