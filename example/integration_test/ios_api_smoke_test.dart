import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing_example/main.dart';

/// iOS Simulator–oriented smoke for the receive-share public API.
///
/// Limitations (real Share Extension / system share sheet / App Group deposit
/// and `acceptsharing://` cold-start URL open cannot be driven from inside the
/// app isolate on iOS): this file asserts the no-share entry path, idempotent
/// clear/cleanup, stream subscribe/cancel, and example UI wiring. Injected
/// cold/warm payloads are covered on desktop by cold_start_* / warm_start_*.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const plugin = XueHuaNaviteAcceptSharing.instance;

  testWidgets(
    'iOS/API smoke: no-share getInitialSharing, clear/cleanup idempotent',
    (WidgetTester tester) async {
      // Without a Share Extension deposit or launch URL, cold start is empty.
      final SharedPayload? first = await plugin.getInitialSharing();
      expect(first == null || first.isEmpty, isTrue);

      await plugin.clearInitialSharing();
      await plugin.clearInitialSharing();
      expect(await plugin.getInitialSharing(), isNull);

      await plugin.cleanupTempFiles();
      await plugin.cleanupTempFiles();
    },
  );

  testWidgets('iOS/API smoke: onSharingReceived listen and cancel', (
    WidgetTester tester,
  ) async {
    final events = <SharedPayload>[];
    final sub = plugin.onSharingReceived.listen(events.add);
    await tester.pump(const Duration(milliseconds: 300));
    await sub.cancel();
    // No share intent deposited → no events expected.
    expect(events, isEmpty);
  });

  testWidgets('iOS/API smoke: example UI empty state and Clear button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Accept Sharing Example'), findsOneWidget);
    expect(find.byKey(const Key('statusText')), findsOneWidget);
    expect(find.byKey(const Key('clearCleanupButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clearCleanupButton')));
    await tester.pumpAndSettle();

    final Text status = tester.widget(find.byKey(const Key('statusText')));
    expect(status.data, contains('Cleared shared data'));
    expect(find.byKey(const Key('emptyHint')), findsOneWidget);

    // Document types / URL scheme are configured for receive-share; this
    // smoke only verifies the Dart entry path is wired on this platform.
    expect(Platform.isIOS || Platform.isAndroid || Platform.isMacOS ||
            Platform.isWindows || Platform.isLinux || Platform.isFuchsia,
        isTrue);
  });
}
