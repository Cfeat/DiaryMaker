import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('PrivateNote shows lock gate before diary UI', (tester) async {
    await pumpPrivateNote(tester, unlocked: false);
    expect(find.text('PrivateNote'), findsWidgets);
    expect(find.byKey(const Key('lock_pin_field')), findsOneWidget);
  });
}
