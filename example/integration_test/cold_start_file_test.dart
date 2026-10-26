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
///   flutter drive -d linux \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/cold_start_file_test.dart \
///     -a /tmp/share_test_assets/hello.txt
String coldStartShareFilePath() {
  return [
    Directory.systemTemp.path,
    'share_test_assets',
    'hello.txt',
  ].join(Platform.pathSeparator);
}

String normalizePath(String value) {
  return File(value).absolute.path.replaceAll('/', r'\').toLowerCase();
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