import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing_example/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const XueHuaNaviteAcceptSharing plugin = XueHuaNaviteAcceptSharing();

  testWidgets('app launches and shows Accept Sharing Example', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Accept Sharing Example'), findsOneWidget);
    expect(find.byKey(const Key('statusText')), findsOneWidget);
    expect(find.byKey(const Key('clearCleanupButton')), findsOneWidget);
  });

  testWidgets('getInitialSharing clearInitialSharing cleanupTempFiles API', (
    WidgetTester tester,
  ) async {
    // Do not pump MyApp first — it consumes and clears the cold-start payload.
    final SharedPayload? payload = await plugin.getInitialSharing();
    // Without share args: null. With --text / file args: non-empty.
    expect(payload == null || payload.isNotEmpty, isTrue);

    await plugin.clearInitialSharing();
    expect(await plugin.getInitialSharing(), isNull);

    await plugin.cleanupTempFiles();
  });

  testWidgets('Clear & Cleanup button resets UI state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const Key('clearCleanupButton')));
    await tester.pumpAndSettle();

    final Text status = tester.widget(find.byKey(const Key('statusText')));
    expect(
      status.data,
      contains('Cleared shared data and cleaned up temporary files.'),
    );
    expect(find.byKey(const Key('emptyHint')), findsOneWidget);
  });

  testWidgets('onSharingReceived stream is subscribable', (
    WidgetTester tester,
  ) async {
    // Linux currently has no warm-start IPC; the stream must still be
    // listen-able without throwing. We only assert subscription succeeds.
    final sub = plugin.onSharingReceived.listen((_) {});
    await tester.pump(const Duration(milliseconds: 200));
    await sub.cancel();
  });
}
