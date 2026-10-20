import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_platform_interface.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockXueHuaNaviteAcceptSharingPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteAcceptSharingPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final XueHuaNaviteAcceptSharingPlatform initialPlatform = XueHuaNaviteAcceptSharingPlatform.instance;

  test('$MethodChannelXueHuaNaviteAcceptSharing is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelXueHuaNaviteAcceptSharing>());
  });

  test('getPlatformVersion', () async {
    XueHuaNaviteAcceptSharing xueHuaNaviteAcceptSharingPlugin = XueHuaNaviteAcceptSharing();
    MockXueHuaNaviteAcceptSharingPlatform fakePlatform = MockXueHuaNaviteAcceptSharingPlatform();
    XueHuaNaviteAcceptSharingPlatform.instance = fakePlatform;

    expect(await xueHuaNaviteAcceptSharingPlugin.getPlatformVersion(), '42');
  });
}
