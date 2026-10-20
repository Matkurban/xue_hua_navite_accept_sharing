import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelXueHuaNaviteAcceptSharing platform =
      MethodChannelXueHuaNaviteAcceptSharing();
  const MethodChannel channel = MethodChannel('xue_hua_navite_accept_sharing');

  Map<String, Object?>? mockInitialPayload;
  bool clearCalled = false;
  bool cleanupCalled = false;

  setUp(() {
    mockInitialPayload = <String, Object?>{
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'type': 'image',
          'content': '/cache/shared_files/photo.png',
          'fileName': 'photo.png',
          'mimeType': 'image/png',
          'fileSize': 102400,
        },
        <String, Object?>{
          'type': 'file',
          'content': '/cache/shared_files/archive.zip',
          'fileName': 'archive.zip',
          'mimeType': 'application/zip',
          'fileSize': 512000,
        },
      ],
      'text': 'Shared 2 files',
      'subject': 'Batch Share',
    };
    clearCalled = false;
    cleanupCalled = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getInitialSharing':
              return mockInitialPayload;
            case 'clearInitialSharing':
              clearCalled = true;
              mockInitialPayload = null;
              return null;
            case 'cleanupTempFiles':
              cleanupCalled = true;
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getInitialSharing deserializes multiple shared files and text', () async {
    final payload = await platform.getInitialSharing();
    expect(payload, isNotNull);
    expect(payload!.items.length, 2);
    expect(payload.items[0].type, SharedItemType.image);
    expect(payload.items[0].fileName, 'photo.png');
    expect(payload.items[1].type, SharedItemType.file);
    expect(payload.items[1].fileName, 'archive.zip');
    expect(payload.text, 'Shared 2 files');
    expect(payload.subject, 'Batch Share');
  });

  test('clearInitialSharing and cleanupTempFiles invoke method channel', () async {
    await platform.clearInitialSharing();
    expect(clearCalled, isTrue);
    expect(await platform.getInitialSharing(), isNull);

    await platform.cleanupTempFiles();
    expect(cleanupCalled, isTrue);
  });
}
