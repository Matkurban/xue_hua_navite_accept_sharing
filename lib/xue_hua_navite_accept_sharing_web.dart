import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'src/shared_models.dart';
import 'xue_hua_navite_accept_sharing_platform_interface.dart';

/// A Web implementation of [XueHuaNaviteAcceptSharingPlatform] supporting the
/// PWA Web Share Target API (both GET query parameters and POST multipart files
/// forwarded via `BroadcastChannel` or `window.postMessage` / Service Worker).
class XueHuaNaviteAcceptSharingWeb extends XueHuaNaviteAcceptSharingPlatform {
  /// Constructs a [XueHuaNaviteAcceptSharingWeb].
  XueHuaNaviteAcceptSharingWeb() {
    _initListeners();
  }

  /// Registers this class as the default instance of
  /// [XueHuaNaviteAcceptSharingPlatform].
  static void registerWith(Registrar registrar) {
    XueHuaNaviteAcceptSharingPlatform.instance = XueHuaNaviteAcceptSharingWeb();
  }

  final StreamController<SharedPayload> _controller =
      StreamController<SharedPayload>.broadcast();
  final List<String> _createdObjectUrls = <String>[];
  web.BroadcastChannel? _broadcastChannel;
  SharedPayload? _initialPayload;
  bool _initialChecked = false;

  void _initListeners() {
    try {
      _broadcastChannel = web.BroadcastChannel('xue_hua_navite_accept_sharing');
      _broadcastChannel!.onmessage = (web.MessageEvent event) {
        final payload = _parseJsEventData(event.data);
        if (payload != null && payload.isNotEmpty) {
          _initialPayload ??= payload;
          _controller.add(payload);
        }
      }.toJS;
    } catch (_) {
      // BroadcastChannel may not be supported in some restricted contexts.
    }

    web.window.addEventListener(
      'message',
      (web.Event event) {
        if (event.isA<web.MessageEvent>()) {
          final messageEvent = event as web.MessageEvent;
          final payload = _parseJsEventData(messageEvent.data);
          if (payload != null && payload.isNotEmpty) {
            _initialPayload ??= payload;
            _controller.add(payload);
          }
        }
      }.toJS,
    );

    final swContainer = web.window.navigator.serviceWorker;
    swContainer.addEventListener(
      'message',
      (web.Event event) {
        if (event.isA<web.MessageEvent>()) {
          final messageEvent = event as web.MessageEvent;
          final payload = _parseJsEventData(messageEvent.data);
          if (payload != null && payload.isNotEmpty) {
            _initialPayload ??= payload;
            _controller.add(payload);
          }
        }
      }.toJS,
    );
  }

  SharedPayload? _parseJsEventData(JSAny? data) {
    if (data == null) {
      return null;
    }
    final dartObj = data.dartify();
    if (dartObj is! Map) {
      return null;
    }
    final map = dartObj.cast<Object?, Object?>();
    if (map['channel'] != null &&
        map['channel'] != 'xue_hua_navite_accept_sharing') {
      return null;
    }

    final rawItems = map['items'];
    final items = <SharedMediaItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          final itemMap = raw.cast<Object?, Object?>();
          final rawBlob = itemMap['blob'];
          String content = (itemMap['content'] ?? itemMap['path'] ?? '')
              .toString();
          String? fileName = itemMap['fileName']?.toString();
          String? mimeType = itemMap['mimeType']?.toString();
          int? fileSize;
          final rawSize = itemMap['fileSize'];
          if (rawSize is num) {
            fileSize = rawSize.toInt();
          }

          Uint8List? bytes;
          final rawBytes = itemMap['bytes'];
          if (rawBytes is Uint8List) {
            bytes = rawBytes;
          } else if (rawBytes is ByteBuffer) {
            bytes = rawBytes.asUint8List();
          } else if (rawBytes is List<int>) {
            bytes = Uint8List.fromList(rawBytes);
          }

          final jsBlob = rawBlob?.jsify();
          if (jsBlob != null && jsBlob.isA<web.Blob>()) {
            final blob = jsBlob as web.Blob;
            final url = web.URL.createObjectURL(blob);
            _createdObjectUrls.add(url);
            content = url;
            fileSize ??= blob.size;
            if (mimeType == null || mimeType.isEmpty) {
              mimeType = blob.type;
            }
            if (blob.isA<web.File>()) {
              final webFile = blob as web.File;
              fileName ??= webFile.name;
            }
          }

          final type = SharedItemType.fromString(
            itemMap['type']?.toString(),
            mimeType: mimeType,
            content: content,
          );
          items.add(
            SharedMediaItem(
              type: type,
              content: content,
              fileName: fileName,
              mimeType: mimeType,
              fileSize: fileSize,
              bytes: bytes,
            ),
          );
        }
      }
    }

    final text = map['text']?.toString();
    final subject = (map['subject'] ?? map['title'])?.toString();
    if (items.isEmpty && text != null && text.isNotEmpty) {
      items.add(
        SharedMediaItem(
          type: SharedItemType.infer(content: text),
          content: text,
          mimeType: 'text/plain',
          extra: subject != null ? <String, dynamic>{'subject': subject} : null,
        ),
      );
    }

    final payload = SharedPayload(items: items, text: text, subject: subject);
    return payload.isNotEmpty ? payload : null;
  }

  SharedPayload? _parseUrlQueryParams() {
    final uri = Uri.tryParse(web.window.location.href);
    if (uri == null || uri.queryParameters.isEmpty) {
      return null;
    }
    final title =
        uri.queryParameters['title'] ?? uri.queryParameters['subject'];
    final text = uri.queryParameters['text'];
    final sharedUrl = uri.queryParameters['url'];

    final items = <SharedMediaItem>[];
    if (text != null && text.trim().isNotEmpty) {
      items.add(
        SharedMediaItem(
          type: SharedItemType.infer(content: text),
          content: text,
          mimeType: 'text/plain',
          extra: title != null ? <String, dynamic>{'subject': title} : null,
        ),
      );
    }
    if (sharedUrl != null && sharedUrl.trim().isNotEmpty) {
      items.add(
        SharedMediaItem(
          type: SharedItemType.url,
          content: sharedUrl,
          mimeType: 'text/uri-list',
          extra: title != null ? <String, dynamic>{'subject': title} : null,
        ),
      );
    }

    if (items.isEmpty) {
      return null;
    }
    return SharedPayload(items: items, text: text ?? sharedUrl, subject: title);
  }

  @override
  Future<SharedPayload?> getInitialSharing() async {
    if (!_initialChecked) {
      _initialChecked = true;
      _initialPayload ??= _parseUrlQueryParams();
      try {
        web.window.navigator.serviceWorker.controller?.postMessage(
          <String, String>{'type': 'xue_hua_request_initial_sharing'}.jsify(),
        );
      } catch (_) {
        // Ignore if service worker controller is not active.
      }
    }
    return _initialPayload;
  }

  @override
  Stream<SharedPayload> get onSharingReceived => _controller.stream;

  @override
  Future<void> clearInitialSharing() async {
    _initialPayload = null;
  }

  @override
  Future<void> cleanupTempFiles() async {
    for (final url in _createdObjectUrls) {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    }
    _createdObjectUrls.clear();
  }
}
