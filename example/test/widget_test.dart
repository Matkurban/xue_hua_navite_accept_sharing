import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xue_hua_navite_accept_sharing_example/main.dart';

void main() {
  testWidgets('Verify Accept Sharing example UI renders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Accept Sharing Example'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data?.startsWith('Status:') ?? false),
      ),
      findsOneWidget,
    );
  });
}
