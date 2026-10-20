export 'src/shared_models.dart';

import 'src/shared_models.dart';
import 'xue_hua_navite_accept_sharing_platform_interface.dart';

/// Entry point for receiving shared text, URLs, and arbitrary files across
/// Android, iOS, macOS, Windows, Linux, and Web.
class XueHuaNaviteAcceptSharing {
  /// Creates a [XueHuaNaviteAcceptSharing] instance.
  const XueHuaNaviteAcceptSharing();

  /// Convenient singleton instance.
  static const XueHuaNaviteAcceptSharing instance =
      XueHuaNaviteAcceptSharing();

  /// Returns the [SharedPayload] that launched the application (cold start),
  /// or `null` if no shared content was present at launch.
  Future<SharedPayload?> getInitialSharing() {
    return XueHuaNaviteAcceptSharingPlatform.instance.getInitialSharing();
  }

  /// Emits a [SharedPayload] whenever new shared text or files arrive while
  /// the application is already running (warm/hot start).
  Stream<SharedPayload> get onSharingReceived {
    return XueHuaNaviteAcceptSharingPlatform.instance.onSharingReceived;
  }

  /// Clears the cached initial sharing data so it will not be returned again
  /// on subsequent [getInitialSharing] calls.
  Future<void> clearInitialSharing() {
    return XueHuaNaviteAcceptSharingPlatform.instance.clearInitialSharing();
  }

  /// Removes temporary shared file copies created in the application's cache
  /// container.
  Future<void> cleanupTempFiles() {
    return XueHuaNaviteAcceptSharingPlatform.instance.cleanupTempFiles();
  }
}
