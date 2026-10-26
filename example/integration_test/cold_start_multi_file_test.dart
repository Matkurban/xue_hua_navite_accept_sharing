import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

/// Run with two existing files passed via `-a path1 -a path2`.
String assetDir() =>
    [Directory.systemTemp.path, 'share_test_assets'].join(Platform.pathSeparator);

String normalizePath(String value) =>
    File(value).absolute.path.replaceAll('/', r'\').toLowerCase();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const plugin = XueHuaNaviteAcceptSharing();
  final a = [assetDir(), 'hello.txt'].join(Platform.pathSeparator);
  final b = [assetDir(), 'second.txt'].join(Platform.pathSeparator);

  testWidgets('cold start multiple files appear in getInitialSharing', (
    WidgetTester tester,
  ) async {
    expect(File(a).existsSync(), isTrue, reason: a);
    expect(File(b).existsSync(), isTrue, reason: b);

    final SharedPayload? payload = await plugin.getInitialSharing();
    expect(payload, isNotNull);
    expect(payload!.files.length, greaterThanOrEqualTo(2));
    final paths = payload.files.map((f) => normalizePath(f.content)).toSet();
    expect(paths.contains(normalizePath(a)), isTrue);
    expect(paths.contains(normalizePath(b)), isTrue);

    await plugin.clearInitialSharing();
    expect(await plugin.getInitialSharing(), isNull);
  });
}