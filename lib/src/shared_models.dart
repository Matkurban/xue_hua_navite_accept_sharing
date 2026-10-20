import 'dart:typed_data';

/// Categorizes the type of a shared item received from the operating system.
enum SharedItemType {
  /// Plain text content.
  text,

  /// Web URL or custom scheme link.
  url,

  /// Image file (`image/*`).
  image,

  /// Video file (`video/*`).
  video,

  /// Audio file (`audio/*`).
  audio,

  /// Arbitrary file of any other type (e.g., PDF, ZIP, DOCX, APK, binary).
  file;

  /// Parses a [SharedItemType] from its string name, or infers it from
  /// [mimeType] and [content].
  static SharedItemType fromString(
    String? raw, {
    String? mimeType,
    String? content,
  }) {
    if (raw != null) {
      final normalized = raw.trim().toLowerCase();
      for (final value in SharedItemType.values) {
        if (value.name == normalized) {
          return value;
        }
      }
    }
    return infer(mimeType: mimeType, content: content);
  }

  /// Infers the [SharedItemType] from a [mimeType] or [content] string.
  static SharedItemType infer({
    String? mimeType,
    String? content,
    bool isFilePath = false,
  }) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.startsWith('image/')) {
      return SharedItemType.image;
    }
    if (normalizedMime.startsWith('video/')) {
      return SharedItemType.video;
    }
    if (normalizedMime.startsWith('audio/')) {
      return SharedItemType.audio;
    }
    if (isFilePath) {
      return SharedItemType.file;
    }
    if (normalizedMime == 'text/uri-list' ||
        normalizedMime == 'text/x-moz-url') {
      return SharedItemType.url;
    }
    if (normalizedMime == 'text/plain' && content != null) {
      return _looksLikeUrl(content) ? SharedItemType.url : SharedItemType.text;
    }
    if (normalizedMime.isNotEmpty) {
      return SharedItemType.file;
    }
    if (content != null && _looksLikeUrl(content)) {
      return SharedItemType.url;
    }
    return SharedItemType.text;
  }

  static bool _looksLikeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.contains('\n') || trimmed.contains(' ')) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return false;
    }
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }
}

/// Represents a single shared item (text, URL, or file of any type).
class SharedMediaItem {
  /// Creates a [SharedMediaItem].
  const SharedMediaItem({
    required this.type,
    required this.content,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.bytes,
    this.extra,
  });

  /// The categorized type of this shared item.
  final SharedItemType type;

  /// For file items ([isFile] is `true`), this is the local file path on native
  /// platforms or a Blob object URL on Web.
  /// For [SharedItemType.text] and [SharedItemType.url], this is the text or
  /// URL string itself.
  final String content;

  /// The original file name (with extension), if this item is a file.
  final String? fileName;

  /// The detected MIME type (e.g., `image/png`, `application/pdf`, `text/plain`).
  final String? mimeType;

  /// The file size in bytes, if known.
  final int? fileSize;

  /// Optional in-memory bytes (primarily populated on Web or inline binary shares).
  final Uint8List? bytes;

  /// Optional platform-specific metadata (e.g., `subject`, `duration`, `width`, `height`).
  final Map<String, dynamic>? extra;

  /// Whether this item represents a file or media asset rather than plain text/URL.
  bool get isFile =>
      type == SharedItemType.image ||
      type == SharedItemType.video ||
      type == SharedItemType.audio ||
      type == SharedItemType.file;

  /// Deserializes a [SharedMediaItem] from a platform channel map.
  factory SharedMediaItem.fromMap(Map<Object?, Object?> map) {
    final content = (map['content'] ?? map['path'] ?? '').toString();
    final fileName = map['fileName']?.toString();
    final mimeType = map['mimeType']?.toString();
    final rawType = map['type']?.toString();

    final rawSize = map['fileSize'];
    int? fileSize;
    if (rawSize is int) {
      fileSize = rawSize;
    } else if (rawSize is num) {
      fileSize = rawSize.toInt();
    } else if (rawSize is String) {
      fileSize = int.tryParse(rawSize);
    }

    Uint8List? bytes;
    final rawBytes = map['bytes'];
    if (rawBytes is Uint8List) {
      bytes = rawBytes;
    } else if (rawBytes is List<int>) {
      bytes = Uint8List.fromList(rawBytes);
    }

    Map<String, dynamic>? extra;
    final rawExtra = map['extra'];
    if (rawExtra is Map) {
      extra = rawExtra.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    final type = rawType != null
        ? SharedItemType.fromString(
            rawType,
            mimeType: mimeType,
            content: content,
          )
        : SharedItemType.infer(
            mimeType: mimeType,
            content: content,
            isFilePath: fileName != null && fileName.isNotEmpty,
          );

    return SharedMediaItem(
      type: type,
      content: content,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
      bytes: bytes,
      extra: extra,
    );
  }

  /// Serializes this [SharedMediaItem] into a map suitable for platform channels.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'content': content,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
      if (bytes != null) 'bytes': bytes,
      if (extra != null) 'extra': extra,
    };
  }

  @override
  String toString() {
    return 'SharedMediaItem(type: ${type.name}, content: $content, '
        'fileName: $fileName, mimeType: $mimeType, fileSize: $fileSize)';
  }
}

/// Represents a complete sharing batch received from the operating system or
/// another application.
class SharedPayload {
  /// Creates a [SharedPayload].
  const SharedPayload({
    this.items = const <SharedMediaItem>[],
    this.text,
    this.subject,
  });

  /// All shared items in this batch (files, media, text, or URLs).
  final List<SharedMediaItem> items;

  /// Optional shared text or caption accompanying the share intent.
  final String? text;

  /// Optional share subject or title (e.g., `Intent.EXTRA_SUBJECT` on Android).
  final String? subject;

  /// Returns `true` if there are no shared items and no shared text.
  bool get isEmpty =>
      items.isEmpty && (text == null || text!.trim().isEmpty);

  /// Returns `true` if at least one shared item or non-empty text is present.
  bool get isNotEmpty => !isEmpty;

  /// Convenience getter returning only file/media items ([SharedMediaItem.isFile]).
  List<SharedMediaItem> get files =>
      items.where((item) => item.isFile).toList(growable: false);

  /// Convenience getter returning only text and URL items.
  List<SharedMediaItem> get textItems =>
      items.where((item) => !item.isFile).toList(growable: false);

  /// Deserializes a [SharedPayload] from a platform channel map.
  factory SharedPayload.fromMap(Map<Object?, Object?> map) {
    final rawItems = map['items'];
    final parsedItems = <SharedMediaItem>[];
    if (rawItems is List) {
      for (final element in rawItems) {
        if (element is Map) {
          parsedItems.add(
            SharedMediaItem.fromMap(element.cast<Object?, Object?>()),
          );
        }
      }
    }

    final text = map['text']?.toString();
    final subject = map['subject']?.toString();

    // If text was provided at the top level without a corresponding text item,
    // ensure it's also accessible via items if items is empty.
    if (parsedItems.isEmpty && text != null && text.isNotEmpty) {
      parsedItems.add(
        SharedMediaItem(
          type: SharedItemType.infer(content: text),
          content: text,
          mimeType: 'text/plain',
          extra: subject != null ? <String, dynamic>{'subject': subject} : null,
        ),
      );
    }

    return SharedPayload(
      items: parsedItems,
      text: text ??
          parsedItems
              .where((item) => !item.isFile)
              .map((item) => item.content)
              .firstOrNull,
      subject: subject,
    );
  }

  /// Serializes this [SharedPayload] into a map.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'items': items.map((item) => item.toMap()).toList(),
      if (text != null) 'text': text,
      if (subject != null) 'subject': subject,
    };
  }

  @override
  String toString() {
    return 'SharedPayload(items: ${items.length}, text: $text, subject: $subject)';
  }
}
