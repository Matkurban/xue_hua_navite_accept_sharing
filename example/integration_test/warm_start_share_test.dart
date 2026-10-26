import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing_example/main.dart';

/// Verifies desktop single-instance warm start:
/// a second process with --text forwards into the running window
/// (Linux unique GtkApplication / Windows WM_COPYDATA).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const marker = 'E2E_WARM_SHARE_MARKER';

  testWidgets('second process --text emits into running UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Accept Sharing Example'), findsOneWidget);

    final exe = Platform.resolvedExecutable;
    final result = await Process.run(exe, <String>['--text', marker]);
    // Secondary activation should hand off and exit promptly.
    expect(result.exitCode, 0,
        reason: 'Secondary unique-instance activation should exit 0. '
            'stderr=${result.stderr}');

    // Allow the primary isolate to receive the event channel payload.
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    var sawMarker = false;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.textContaining(marker).evaluate().isNotEmpty) {
        sawMarker = true;
        break;
      }
    }
    expect(sawMarker, isTrue,
        reason: 'Running UI should show warm-start text "$marker"');

    final Text status = tester.widget(find.byKey(const Key('statusText')));
    expect(status.data, contains('Received real-time sharing'));

    await tester.tap(find.byKey(const Key('clearCleanupButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptyHint')), findsOneWidget);
  }, skip: !(Platform.isLinux || Platform.isWindows));
}