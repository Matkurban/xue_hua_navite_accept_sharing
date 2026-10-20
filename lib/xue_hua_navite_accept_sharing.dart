
import 'xue_hua_navite_accept_sharing_platform_interface.dart';

class XueHuaNaviteAcceptSharing {
  Future<String?> getPlatformVersion() {
    return XueHuaNaviteAcceptSharingPlatform.instance.getPlatformVersion();
  }
}
