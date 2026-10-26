import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

/// Run with:
///   flutter drive -d linux \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/cold_start_file_test.dart \
///     -a '/tmp/share_test_assets/hello.txt'
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const plugin = XueHuaNaviteAcceptSharing();
  const path = '/tmp/share_test_assets/hello.txt';

  testWidgets('cold start getInitialSharing returns shared file path', (
    WidgetTester tester,
  ) async {
    expect(File(path).existsSync(), isTrue,
        reason: 'Test asset must exist before drive');

    final SharedPayload? payload = await plugin.getInitialSharing();
    expect(payload, isNotNull);
    expect(payload!.files, isNotEmpty);
    final fileItem = payload.files.first;
    expect(fileItem.content, path);
    expect(fileItem.fileName, 'hello.txt');
    expect(fileItem.isFile, isTrue);

    await plugin.clearInitialSharing();
    expect(await plugin.getInitialSharing(), isNull);
    await plugin.cleanupTempFiles();
  });
}
