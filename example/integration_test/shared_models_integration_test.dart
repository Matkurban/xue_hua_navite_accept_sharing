import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

/// Covers public model API (SharedItemType / SharedMediaItem / SharedPayload)
/// that unit tests only partially exercise. Runs on every platform including
/// iOS Simulator — no native share intent required.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SharedItemType.infer / fromString', () {
    testWidgets('classifies mime and content for all public types', (
      WidgetTester tester,
    ) async {
      expect(
        SharedItemType.infer(mimeType: 'image/jpeg'),
        SharedItemType.image,
      );
      expect(
        SharedItemType.infer(mimeType: 'video/mp4'),
        SharedItemType.video,
      );
      expect(
        SharedItemType.infer(mimeType: 'audio/mpeg'),
        SharedItemType.audio,
      );
      expect(
        SharedItemType.infer(mimeType: 'application/pdf'),
        SharedItemType.file,
      );
      expect(
        SharedItemType.infer(mimeType: 'text/uri-list'),
        SharedItemType.url,
      );
      expect(
        SharedItemType.infer(
          mimeType: 'text/plain',
          content: 'https://example.com/path',
        ),
        SharedItemType.url,
      );
      expect(
        SharedItemType.infer(mimeType: 'text/plain', content: 'hello world'),
        SharedItemType.text,
      );
      expect(
        SharedItemType.infer(content: 'https://flutter.dev', isFilePath: false),
        SharedItemType.url,
      );
      expect(
        SharedItemType.infer(isFilePath: true),
        SharedItemType.file,
      );

      expect(SharedItemType.fromString('IMAGE'), SharedItemType.image);
      expect(SharedItemType.fromString('Video'), SharedItemType.video);
      expect(SharedItemType.fromString('audio'), SharedItemType.audio);
      expect(
        SharedItemType.fromString(
          'unknown',
          mimeType: 'application/zip',
        ),
        SharedItemType.file,
      );
    });
  });

  group('SharedMediaItem / SharedPayload round-trip', () {
    testWidgets('fromMap/toMap preserve image/video/audio/file/url/text', (
      WidgetTester tester,
    ) async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
      final items = <SharedMediaItem>[
        SharedMediaItem.fromMap(<Object?, Object?>{
          'type': 'image',
          'content': '/tmp/shared_files/a.png',
          'fileName': 'a.png',
          'mimeType': 'image/png',
          'fileSize': 100,
        }),
        SharedMediaItem.fromMap(<Object?, Object?>{
          'type': 'video',
          'content': '/tmp/shared_files/b.mp4',
          'fileName': 'b.mp4',
          'mimeType': 'video/mp4',
          'fileSize': 200,
          'extra': <Object?, Object?>{'duration': 12},
        }),
        SharedMediaItem.fromMap(<Object?, Object?>{
          'type': 'audio',
          'content': '/tmp/shared_files/c.mp3',
          'fileName': 'c.mp3',
          'mimeType': 'audio/mpeg',
          'fileSize': 50,
        }),
        SharedMediaItem.fromMap(<Object?, Object?>{
          'type': 'file',
          'content': '/tmp/shared_files/d.pdf',
          'fileName': 'd.pdf',
          'mimeType': 'application/pdf',
          'fileSize': 300,
          'bytes': bytes,
        }),
        SharedMediaItem.fromMap(<Object?, Object?>{
          'type': 'url',
          'content': 'https://example.com/e2e',
          'mimeType': 'text/uri-list',
        }),
        SharedMediaItem.fromMap(<Object?, Object?>{
          'path': 'plain text body',
          'mimeType': 'text/plain',
        }),
      ];

      expect(items[0].type, SharedItemType.image);
      expect(items[0].isFile, isTrue);
      expect(items[1].type, SharedItemType.video);
      expect(items[1].extra?['duration'], 12);
      expect(items[2].type, SharedItemType.audio);
      expect(items[3].type, SharedItemType.file);
      expect(items[3].bytes, bytes);
      expect(items[4].type, SharedItemType.url);
      expect(items[4].isFile, isFalse);
      expect(items[5].type, SharedItemType.text);
      expect(items[5].content, 'plain text body');

      final payload = SharedPayload(
        items: items,
        text: 'caption',
        subject: 'Subject Title',
      );
      expect(payload.isNotEmpty, isTrue);
      expect(payload.files.length, 4);
      expect(payload.textItems.length, 2);
      expect(payload.subject, 'Subject Title');

      final roundTrip = SharedPayload.fromMap(payload.toMap());
      expect(roundTrip.items.length, items.length);
      expect(roundTrip.text, 'caption');
      expect(roundTrip.subject, 'Subject Title');
      expect(roundTrip.files.first.fileName, 'a.png');
      expect(roundTrip.toString(), contains('SharedPayload'));
      expect(items[0].toString(), contains('SharedMediaItem'));
    });

    testWidgets('empty payload and top-level text fallback', (
      WidgetTester tester,
    ) async {
      const empty = SharedPayload();
      expect(empty.isEmpty, isTrue);
      expect(empty.files, isEmpty);
      expect(empty.textItems, isEmpty);

      final fromTextOnly = SharedPayload.fromMap(<Object?, Object?>{
        'text': 'https://only-text.example',
        'subject': 'Link',
      });
      expect(fromTextOnly.isNotEmpty, isTrue);
      expect(fromTextOnly.items, isNotEmpty);
      expect(fromTextOnly.items.first.type, SharedItemType.url);
      expect(fromTextOnly.subject, 'Link');
    });
  });
}
