import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/shared_models.dart';
import 'xue_hua_navite_accept_sharing_method_channel.dart';

/// The interface that platform-specific implementations of
/// `xue_hua_navite_accept_sharing` must extend.
abstract class XueHuaNaviteAcceptSharingPlatform extends PlatformInterface {
  /// Constructs a [XueHuaNaviteAcceptSharingPlatform].
  XueHuaNaviteAcceptSharingPlatform() : super(token: _token);

  static final Object _token = Object();

  static XueHuaNaviteAcceptSharingPlatform _instance =
      MethodChannelXueHuaNaviteAcceptSharing();

  /// The default instance of [XueHuaNaviteAcceptSharingPlatform] to use.
  ///
  /// Defaults to [MethodChannelXueHuaNaviteAcceptSharing].
  static XueHuaNaviteAcceptSharingPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XueHuaNaviteAcceptSharingPlatform]
  /// when they register themselves.
  static set instance(XueHuaNaviteAcceptSharingPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the [SharedPayload] that launched the application on cold start,
  /// or `null` if the application was launched normally.
  Future<SharedPayload?> getInitialSharing() {
    throw UnimplementedError('getInitialSharing() has not been implemented.');
  }

  /// A broadcast stream emitting [SharedPayload] events whenever the
  /// application receives new shared content while already running.
  Stream<SharedPayload> get onSharingReceived {
    throw UnimplementedError('onSharingReceived has not been implemented.');
  }

  /// Clears the cached initial sharing payload so that subsequent calls to
  /// [getInitialSharing] return `null`.
  Future<void> clearInitialSharing() {
    throw UnimplementedError('clearInitialSharing() has not been implemented.');
  }

  /// Deletes temporary shared file copies created by the plugin in the
  /// application's cache directory.
  Future<void> cleanupTempFiles() {
    throw UnimplementedError('cleanupTempFiles() has not been implemented.');
  }
}
