import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/shared_models.dart';
import 'xue_hua_navite_accept_sharing_platform_interface.dart';

/// An implementation of [XueHuaNaviteAcceptSharingPlatform] that uses method
/// and event channels.
class MethodChannelXueHuaNaviteAcceptSharing
    extends XueHuaNaviteAcceptSharingPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'xue_hua_navite_accept_sharing',
  );

  /// The event channel used to receive real-time sharing events from the native
  /// platform.
  @visibleForTesting
  final EventChannel eventChannel = const EventChannel(
    'xue_hua_navite_accept_sharing/events',
  );

  Stream<SharedPayload>? _onSharingReceived;

  @override
  Future<SharedPayload?> getInitialSharing() async {
    final raw = await methodChannel.invokeMapMethod<Object?, Object?>(
      'getInitialSharing',
    );
    if (raw == null) {
      return null;
    }
    final payload = SharedPayload.fromMap(raw);
    return payload.isNotEmpty ? payload : null;
  }

  @override
  Stream<SharedPayload> get onSharingReceived {
    return _onSharingReceived ??= eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map(
          (event) =>
              SharedPayload.fromMap((event as Map).cast<Object?, Object?>()),
        )
        .where((payload) => payload.isNotEmpty);
  }

  @override
  Future<void> clearInitialSharing() async {
    await methodChannel.invokeMethod<void>('clearInitialSharing');
  }

  @override
  Future<void> cleanupTempFiles() async {
    await methodChannel.invokeMethod<void>('cleanupTempFiles');
  }
}
