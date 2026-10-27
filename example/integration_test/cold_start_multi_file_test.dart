import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

/// Desktop argv cold-start multi-file (flutter drive `-a path1 -a path2`).
///
/// Run with two existing files passed via `-a path1 -a path2`.
///
/// Skipped on iOS/Android: mobile has no ProcessInfo argv file injection; iOS
/// file payloads are covered by ios_api_smoke_test (+ real Share / openURL).
String assetDir() {
  if (Platform.isWindows) {
    return [
      Directory.systemTemp.path,
      'share_test_assets',
    ].join(Platform.pathSeparator);
  }
  return '/tmp/share_test_assets';
}

String normalizePath(String value) {
  final absolute = File(value).absolute.path;
  if (Platform.isWindows) {
    return absolute.replaceAll('/', r'\').toLowerCase();
  }
  try {
    return File(absolute).resolveSymbolicLinksSync().toLowerCase();
  } catch (_) {
    return absolute.replaceAll('\\', '/').toLowerCase();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const plugin = XueHuaNaviteAcceptSharing();
  final a = [assetDir(), 'hello.txt'].join(Platform.pathSeparator);
  final b = [assetDir(), 'second.txt'].join(Platform.pathSeparator);

  testWidgets(
    'cold start multiple files appear in getInitialSharing',
    (WidgetTester tester) async {
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
    },
    // Desktop ProcessInfo argv only; iOS uses App Group / openURL (see ios_api_smoke).
    skip: !(Platform.isWindows || Platform.isLinux || Platform.isMacOS),
  );
}
