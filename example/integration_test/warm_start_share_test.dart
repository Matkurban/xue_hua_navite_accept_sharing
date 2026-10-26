import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing_example/main.dart';

/// Verifies desktop warm start:
/// - Linux unique GtkApplication / Windows WM_COPYDATA: second process `--text`
/// - macOS: Share Extension / URL-scheme handoff (`acceptsharing://share?payload=`)
///   while the app is already running (no single-instance argv forwarder).
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

  testWidgets('macOS Share Extension payload handoff emits into running UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Accept Sharing Example'), findsOneWidget);

    final payload = <String, Object?>{
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'text',
          'content': marker,
          'mimeType': 'text/plain',
        },
      ],
      'text': marker,
    };
    final raw = utf8.encode(jsonEncode(payload));
    final dir = Directory('/tmp/xue_hua_accept_sharing');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    File('${dir.path}/payload.json').writeAsBytesSync(raw);

    // Share Extension writes this manifest (or App Group) then opens
    // acceptsharing://. Under flutter drive, `open acceptsharing://` often
    // starts a *second* process that consumes /tmp before this isolate can,
    // so poll in-process via getInitialSharing — same checkAppGroupPayload
    // path as NSApplication.didBecomeActiveNotification.
    const plugin = XueHuaNaviteAcceptSharing();
    await plugin.getInitialSharing();

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    var sawMarker = false;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.textContaining(marker).evaluate().isNotEmpty) {
        sawMarker = true;
        break;
      }
    }
    expect(sawMarker, isTrue,
        reason: 'Running UI should show Share Extension warm-start text "$marker"');

    final Text status = tester.widget(find.byKey(const Key('statusText')));
    expect(status.data, contains('Received real-time sharing'));

    await tester.tap(find.byKey(const Key('clearCleanupButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptyHint')), findsOneWidget);
  }, skip: !Platform.isMacOS);

  testWidgets('macOS Open With file while running emits into UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Accept Sharing Example'), findsOneWidget);

    const path = '/tmp/share_test_assets/hello.txt';
    expect(File(path).existsSync(), isTrue, reason: path);

    // Platform.resolvedExecutable: .../Foo.app/Contents/MacOS/Foo
    final exe = File(Platform.resolvedExecutable);
    final appBundle = exe.parent.parent.parent.path;
    expect(appBundle.endsWith('.app'), isTrue, reason: appBundle);

    final result = await Process.run('open', <String>[path, '-a', appBundle]);
    expect(result.exitCode, 0,
        reason: 'open file -a app should succeed. stderr=${result.stderr}');

    final deadline = DateTime.now().add(const Duration(seconds: 10));
    var sawFile = false;
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.textContaining('hello.txt').evaluate().isNotEmpty) {
        sawFile = true;
        break;
      }
    }
    expect(sawFile, isTrue,
        reason: 'Running UI should show Open-With file hello.txt');

    final Text status = tester.widget(find.byKey(const Key('statusText')));
    expect(status.data, contains('Received real-time sharing'));

    await tester.tap(find.byKey(const Key('clearCleanupButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('emptyHint')), findsOneWidget);
  }, skip: !Platform.isMacOS);
}
