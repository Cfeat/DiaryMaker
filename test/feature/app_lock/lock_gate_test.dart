import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/memory_entry_repository.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('C1: locked state cannot reach Home / timeline content',
      (tester) async {
    final repo = MemoryEntryRepository();
    await repo.create(
      Entry(
        id: 'secret-1',
        title: 'Secret title',
        content: 'Secret body',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await pumpPrivateNote(tester, repository: repo, unlocked: false);

    expect(find.byKey(const Key('lock_pin_field')), findsOneWidget);
    expect(find.text('Secret title'), findsNothing);
    expect(find.byKey(const Key('timeline_list')), findsNothing);
    expect(find.byKey(const Key('timeline_empty_title')), findsNothing);
    expect(find.byKey(const Key('timeline_new_entry')), findsNothing);
  });

  testWidgets('C1: after unlock, timeline becomes reachable', (tester) async {
    await pumpPrivateNote(tester, unlocked: true);

    expect(find.byKey(const Key('lock_pin_field')), findsNothing);
    expect(find.byKey(const Key('timeline_empty_title')), findsOneWidget);
  });
}
