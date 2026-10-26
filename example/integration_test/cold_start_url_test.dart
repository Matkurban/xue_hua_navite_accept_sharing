import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing_example/main.dart';

/// Run with:
///   flutter drive -d windows|linux \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/cold_start_url_test.dart \
///     -a '--text' -a 'https://example.com/e2e'
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const marker = 'https://example.com/e2e';
  const plugin = XueHuaNaviteAcceptSharing();

  testWidgets('cold start --text URL is classified as url and shown in UI', (
    WidgetTester tester,
  ) async {
    final SharedPayload? payload = await plugin.getInitialSharing();
    expect(payload, isNotNull);
    expect(payload!.items, isNotEmpty);
    expect(payload.items.first.content, marker);
    expect(payload.items.first.type, SharedItemType.url);
    expect(payload.text, marker);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining(marker), findsWidgets);

    await tester.tap(find.byKey(const Key('clearCleanupButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptyHint')), findsOneWidget);
    expect(await plugin.getInitialSharing(), isNull);
  });
}