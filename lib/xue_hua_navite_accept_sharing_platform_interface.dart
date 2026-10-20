import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'xue_hua_navite_accept_sharing_method_channel.dart';

abstract class XueHuaNaviteAcceptSharingPlatform extends PlatformInterface {
  /// Constructs a XueHuaNaviteAcceptSharingPlatform.
  XueHuaNaviteAcceptSharingPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteAcceptSharingPlatform _instance = MethodChannelXueHuaNaviteAcceptSharing();

  /// The default instance of [XueHuaNaviteAcceptSharingPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteAcceptSharing].
  static XueHuaNaviteAcceptSharingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteAcceptSharingPlatform] when
  /// they register themselves.
  static set instance(XueHuaNaviteAcceptSharingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
