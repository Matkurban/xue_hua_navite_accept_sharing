import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_method_channel.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_platform_interface.dart';

class MockXueHuaNaviteAcceptSharingPlatform
    with MockPlatformInterfaceMixin
    implements XueHuaNaviteAcceptSharingPlatform {
  SharedPayload? initialPayload = const SharedPayload(
    items: <SharedMediaItem>[
      SharedMediaItem(
        type: SharedItemType.file,
        content: '/tmp/shared_files/report.pdf',
        fileName: 'report.pdf',
        mimeType: 'application/pdf',
        fileSize: 2048,
      ),
    ],
    text: 'Quarterly PDF report',
    subject: 'Q3 Report',
  );

  bool tempFilesCleaned = false;
  final StreamController<SharedPayload> controller =
      StreamController<SharedPayload>.broadcast();

  @override
  Future<SharedPayload?> getInitialSharing() async => initialPayload;

  @override
  Stream<SharedPayload> get onSharingReceived => controller.stream;

  @override
  Future<void> clearInitialSharing() async {
    initialPayload = null;
  }

  @override
  Future<void> cleanupTempFiles() async {
    tempFilesCleaned = true;
  }
}

void main() {
  final XueHuaNaviteAcceptSharingPlatform initialPlatform =
      XueHuaNaviteAcceptSharingPlatform.instance;

  test('$MethodChannelXueHuaNaviteAcceptSharing is the default instance', () {
    expect(
      initialPlatform,
      isInstanceOf<MethodChannelXueHuaNaviteAcceptSharing>(),
    );
  });

  test('getInitialSharing, clearInitialSharing, and cleanupTempFiles', () async {
    const plugin = XueHuaNaviteAcceptSharing();
    final fakePlatform = MockXueHuaNaviteAcceptSharingPlatform();
    XueHuaNaviteAcceptSharingPlatform.instance = fakePlatform;

    final payload = await plugin.getInitialSharing();
    expect(payload, isNotNull);
    expect(payload!.isNotEmpty, isTrue);
    expect(payload.subject, 'Q3 Report');
    expect(payload.text, 'Quarterly PDF report');
    expect(payload.files.length, 1);
    expect(payload.files.first.fileName, 'report.pdf');
    expect(payload.files.first.mimeType, 'application/pdf');
    expect(payload.files.first.fileSize, 2048);

    await plugin.clearInitialSharing();
    expect(await plugin.getInitialSharing(), isNull);

    await plugin.cleanupTempFiles();
    expect(fakePlatform.tempFilesCleaned, isTrue);
  });

  test('onSharingReceived emits incoming payloads', () async {
    const plugin = XueHuaNaviteAcceptSharing();
    final fakePlatform = MockXueHuaNaviteAcceptSharingPlatform();
    XueHuaNaviteAcceptSharingPlatform.instance = fakePlatform;

    final receivedFuture = plugin.onSharingReceived.first;
    const incoming = SharedPayload(
      items: <SharedMediaItem>[
        SharedMediaItem(
          type: SharedItemType.url,
          content: 'https://flutter.dev',
          mimeType: 'text/uri-list',
        ),
      ],
      text: 'https://flutter.dev',
    );
    fakePlatform.controller.add(incoming);

    final received = await receivedFuture;
    expect(received.items.first.type, SharedItemType.url);
    expect(received.items.first.content, 'https://flutter.dev');
  });
}
