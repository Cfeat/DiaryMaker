import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/memory_entry_repository.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('C2: empty timeline shows guidance copy', (tester) async {
    await pumpPrivateNote(tester, unlocked: true);

    expect(find.byKey(const Key('timeline_empty_title')), findsOneWidget);
    expect(find.byKey(const Key('timeline_empty_body')), findsOneWidget);
  });

  testWidgets('C2: lists entry title and preview newest-first', (tester) async {
    final repo = MemoryEntryRepository();
    await repo.create(
      Entry(
        id: 'older',
        title: 'Older note',
        content: 'Line A\nLine B\nLine C',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repo.create(
      Entry(
        id: 'newer',
        title: 'Newer note',
        content: 'Fresh first\nFresh second',
        createdAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      ),
    );

    await pumpPrivateNote(tester, repository: repo, unlocked: true);

    expect(find.byKey(const Key('timeline_list')), findsOneWidget);
    expect(find.text('Newer note'), findsOneWidget);
    expect(find.text('Older note'), findsOneWidget);
    expect(find.textContaining('Fresh first'), findsOneWidget);

    final newerY = tester.getTopLeft(find.text('Newer note')).dy;
    final olderY = tester.getTopLeft(find.text('Older note')).dy;
    expect(newerY, lessThan(olderY));
  });
}
