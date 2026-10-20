import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getInitialSharing and clearInitialSharing test', (
    WidgetTester tester,
  ) async {
    const XueHuaNaviteAcceptSharing plugin = XueHuaNaviteAcceptSharing();
    // On normal test launch without share intent, getInitialSharing completes cleanly.
    final SharedPayload? payload = await plugin.getInitialSharing();
    expect(payload == null || payload.isNotEmpty, true);
    await plugin.clearInitialSharing();
    await plugin.cleanupTempFiles();
  });
}
