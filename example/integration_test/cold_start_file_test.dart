import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

/// Shared test asset used by cold-start file drive runs.
///
/// Create it before driving, then pass the same absolute path with `-a`:
///   flutter drive -d windows \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/cold_start_file_test.dart \
///     -a "%TEMP%\share_test_assets\hello.txt"
///   flutter drive -d linux|macos \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/cold_start_file_test.dart \
///     -a /tmp/share_test_assets/hello.txt
///
/// On sandboxed macOS, [Directory.systemTemp] is the container tmp, so drive
/// assets always live under the real `/tmp/share_test_assets` (allowed by the
/// example's temporary-exception entitlement).
String coldStartShareFilePath() {
  if (Platform.isWindows) {
    return [
      Directory.systemTemp.path,
      'share_test_assets',
      'hello.txt',
    ].join(Platform.pathSeparator);
  }
  return '/tmp/share_test_assets/hello.txt';
}

String normalizePath(String value) {
  final absolute = File(value).absolute.path;
  if (Platform.isWindows) {
    return absolute.replaceAll('/', r'\').toLowerCase();
  }
  // macOS: /tmp -> /private/tmp
  try {
    return File(absolute).resolveSymbolicLinksSync().toLowerCase();
  } catch (_) {
    return absolute.replaceAll('\\', '/').toLowerCase();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const plugin = XueHuaNaviteAcceptSharing();
  final path = coldStartShareFilePath();

  testWidgets('cold start getInitialSharing returns shared file path', (
    WidgetTester tester,
  ) async {
    expect(File(path).existsSync(), isTrue,
        reason: 'Test asset must exist before drive: $path');

    final SharedPayload? payload = await plugin.getInitialSharing();
    expect(payload, isNotNull);
    expect(payload!.files, isNotEmpty);
    final fileItem = payload.files.first;
    expect(fileItem.fileName, 'hello.txt');
    expect(fileItem.isFile, isTrue);
    expect(File(fileItem.content).existsSync(), isTrue);
    expect(
      normalizePath(fileItem.content),
      normalizePath(path),
    );

    await plugin.clearInitialSharing();
    expect(await plugin.getInitialSharing(), isNull);
    await plugin.cleanupTempFiles();
  });
}
