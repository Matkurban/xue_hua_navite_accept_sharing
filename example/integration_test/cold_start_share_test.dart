import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing_example/main.dart';

/// Run with:
///   flutter drive -d windows|linux \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/cold_start_share_test.dart \
///     -a '--text' -a 'E2E_SHARE_TEXT_MARKER'
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const marker = 'E2E_SHARE_TEXT_MARKER';
  const plugin = XueHuaNaviteAcceptSharing();

  testWidgets(
    'cold start: API payload, UI shows share, Clear resets, clear empties API',
    (WidgetTester tester) async {
      // 1) Native cold-start payload must be present before MyApp consumes it.
      final SharedPayload? payload = await plugin.getInitialSharing();
      expect(payload, isNotNull,
          reason: 'Expected cold-start payload from --text');
      expect(payload!.isNotEmpty, isTrue);
      expect(payload.text, marker);
      expect(payload.items, isNotEmpty);
      expect(payload.items.first.content, marker);
      expect(
        payload.items.first.type == SharedItemType.text ||
            payload.items.first.type == SharedItemType.url,
        isTrue,
      );

      // 2) UI: MyApp reads initial sharing once and displays it.
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Accept Sharing Example'), findsOneWidget);
      final Text status = tester.widget(find.byKey(const Key('statusText')));
      expect(status.data, contains('Received initial sharing'));
      expect(find.textContaining(marker), findsWidgets);

      // 3) Clear & Cleanup button resets the UI.
      await tester.tap(find.byKey(const Key('clearCleanupButton')));
      await tester.pumpAndSettle();

      final Text cleared = tester.widget(find.byKey(const Key('statusText')));
      expect(cleared.data, contains('Cleared shared data'));
      expect(find.byKey(const Key('emptyHint')), findsOneWidget);

      // 4) API cache stays cleared.
      expect(await plugin.getInitialSharing(), isNull);
      await plugin.cleanupTempFiles();
    },
  );
}