import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:private_note/app/providers.dart';
import 'package:private_note/core/entry/entry.dart';
import 'package:private_note/core/entry/memory_entry_repository.dart';
import 'package:private_note/feature/editor/editor_page.dart';
import 'package:private_note/foundation/platform/dart_io_app_host.dart';

void main() {
  testWidgets('C3: autosave persists after 1s debounce via repository',
      (tester) async {
    final repo = MemoryEntryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(repo),
          appHostProvider.overrideWithValue(
            const FakeAppHost(
              usesDesktopShell: false,
              usesMobileShell: true,
            ),
          ),
          timelineEntriesProvider.overrideWith(_EmptyTimeline.new),
        ],
        child: const MaterialApp(
          home: EditorPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const Key('editor_title_field')),
      'Autosaved',
    );
    await tester.enterText(
      find.byKey(const Key('editor_body_field')),
      'Hello body',
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    final all = await repo.listOrderedByUpdatedAtDesc();
    expect(all, hasLength(1));
    expect(all.first.title, 'Autosaved');
    expect(all.first.content, 'Hello body');
  });

  testWidgets('C3: leaving with unsaved edits shows confirm dialog',
      (tester) async {
    final repo = MemoryEntryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(repo),
          appHostProvider.overrideWithValue(
            const FakeAppHost(
              usesDesktopShell: false,
              usesMobileShell: true,
            ),
          ),
          timelineEntriesProvider.overrideWith(_EmptyTimeline.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditorPage(),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const Key('editor_title_field')),
      'Draft',
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('有未保存的更改'), findsOneWidget);
    expect(find.text('丢弃'), findsOneWidget);
  });
}

class _EmptyTimeline extends TimelineEntriesNotifier {
  @override
  Future<List<Entry>> build() async => [];
}
