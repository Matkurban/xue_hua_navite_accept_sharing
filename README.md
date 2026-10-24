# xue_hua_navite_accept_sharing

[中文](README.zh-CN.md)

A cross-platform Flutter plugin for receiving shares. On **Android, iOS, macOS, Windows, Linux, and Web (PWA)** it accepts **plain text, URLs, and one or many files of any type** (images, videos, audio, PDFs, archives, Office documents, APKs, binary files, and more) shared by the system or by another app. It handles both a **cold start** (the share launches an app that was not running) and a **warm start** (the app is already in the background or foreground and receives the share immediately).

## Contents

1. [Features](#features)
2. [Data model and core API](#data-model-and-core-api)
3. [Complete Dart example](#complete-dart-example)
4. [System share-menu setup](#system-share-menu-setup)
   - [1. macOS (Finder Share sheet, Services menu, and Dock drop)](#1-macos-finder-share-sheet-services-menu-and-dock-drop)
   - [2. iOS (system Share Sheet and Open In)](#2-ios-system-share-sheet-and-open-in)
   - [3. Android (system share sheet intent filters)](#3-android-system-share-sheet-intent-filters)
   - [4. Windows (Send to, Open with, and single-instance WM_COPYDATA)](#4-windows-send-to-open-with-and-single-instance-wm_copydata)
   - [5. Linux (Open with and .desktop launcher)](#5-linux-open-with-and-desktop-launcher)
   - [6. Web (PWA) system share menu (Web Share Target API)](#6-web-pwa-system-share-menu-web-share-target-api)

## Features

| Platform      |                       Text / URL                        |                  Single or multiple files (any type)                   | Cold start (`getInitialSharing`) |      Live stream (`onSharingReceived`)      |              Temp file cleanup (`cleanupTempFiles`)               |
|:--------------|:-------------------------------------------------------:|:----------------------------------------------------------------------:|:--------------------------------:|:-------------------------------------------:|:-----------------------------------------------------------------:|
| **Android**   |                Supported (`ACTION_SEND`)                |          Supported (`ACTION_SEND` / `SEND_MULTIPLE` / `VIEW`)          |            Supported             |          Supported (`onNewIntent`)          |            Supported (clears `cacheDir/shared_files`)             |
| **iOS**       |        Supported (Share Extension / URL scheme)         |            Supported (Open In / AirDrop / Share Extension)             |            Supported             |                  Supported                  | Supported (clears the temp directory and the App Group container) |
| **macOS**     | Supported (Share Extension / `NSServices` / URL scheme) | Supported (Finder Share sheet / Open With / Dock drop / Services menu) |            Supported             |                  Supported                  | Supported (clears the temp directory and the App Group container) |
| **Windows**   |          Supported (`--text` / `WM_COPYDATA`)           |     Supported (Open with / Send to / command line / `WM_COPYDATA`)     |            Supported             |          Supported (`WM_COPYDATA`)          |                             Supported                             |
| **Linux**     |                  Supported (`--text`)                   |              Supported (`.desktop` Open with `%F` / `%U`)              |            Supported             |                  Supported                  |                             Supported                             |
| **Web (PWA)** |           Supported (`share_target` GET/POST)           |            Supported (`share_target` POST + service worker)            |            Supported             | Supported (`BroadcastChannel` / SW message) |              Supported (revokes `Blob` object URLs)               |

## Data model and core API

### 1. `SharedItemType`

- `SharedItemType.text`: plain text
- `SharedItemType.url`: an `http://` or `https://` link
- `SharedItemType.image`: an image file (`image/*`)
- `SharedItemType.video`: a video file (`video/*`)
- `SharedItemType.audio`: an audio file (`audio/*`)
- `SharedItemType.file`: any other file (for example `application/pdf`, `application/zip`, `application/vnd.android.package-archive`, or `application/octet-stream`)

### 2. `SharedMediaItem`

- `type` (`SharedItemType`): detected item type
- `content` (`String`): absolute local path when `isFile` is true (a `Blob` URL on the web); otherwise the text or URL itself
- `fileName` (`String?`): original file name, including the extension
- `mimeType` (`String?`): detected MIME type
- `fileSize` (`int?`): size in bytes
- `bytes` (`Uint8List?`): optional in-memory bytes (web, or when the payload is passed in memory)
- `extra` (`Map<String, dynamic>?`): extra fields, such as a share `subject`
- `isFile` (`bool`): whether this item is a file or other media

### 3. `SharedPayload`

- `items` (`List<SharedMediaItem>`): every item in this share
- `files` (`List<SharedMediaItem>`): file and media items only
- `textItems` (`List<SharedMediaItem>`): plain-text and URL items only
- `text` (`String?`): accompanying text or description
- `subject` (`String?`): share subject or title (for example Android `Intent.EXTRA_SUBJECT`)

### 4. `XueHuaNaviteAcceptSharing`

- `Future<SharedPayload?> getInitialSharing()`: payload that cold-started the app
- `Stream<SharedPayload> get onSharingReceived`: shares received while the app is running
- `Future<void> clearInitialSharing()`: drop the consumed cold-start cache so a rebuild or hot reload does not handle it again
- `Future<void> cleanupTempFiles()`: delete temporary share copies the plugin wrote into the sandbox cache

## Complete Dart example

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

class SharingReceiverPage extends StatefulWidget {
  const SharingReceiverPage({super.key});

  @override
  State<SharingReceiverPage> createState() => _SharingReceiverPageState();
}

class _SharingReceiverPageState extends State<SharingReceiverPage> {
  final _sharing = XueHuaNaviteAcceptSharing.instance;
  StreamSubscription<SharedPayload>? _subscription;
  SharedPayload? _payload;

  @override
  void initState() {
    super.initState();
    _initSharing();
  }

  Future<void> _initSharing() async {
    // 1. Read the payload that cold-started the app.
    final initial = await _sharing.getInitialSharing();
    if (initial != null && initial.isNotEmpty) {
      _handlePayload(initial);
      // Clear the cold-start cache after it has been consumed.
      await _sharing.clearInitialSharing();
    }

    // 2. Listen for shares that arrive while the app is in the background or foreground.
    _subscription = _sharing.onSharingReceived.listen(_handlePayload);
  }

  void _handlePayload(SharedPayload payload) {
    if (!mounted) return;
    setState(() {
      _payload = payload;
    });

    for (final item in payload.items) {
      switch (item.type) {
        case SharedItemType.text:
        case SharedItemType.url:
          debugPrint('Received text or URL: ${item.content}');
          break;
        case SharedItemType.image:
        case SharedItemType.video:
        case SharedItemType.audio:
        case SharedItemType.file:
          debugPrint(
            'Received file: ${item.fileName}, MIME: ${item.mimeType}, '
            'size: ${item.fileSize} bytes, path: ${item.content}',
          );
          final file = File(item.content);
          if (file.existsSync()) {
            debugPrint('Local file is readable, length: ${file.lengthSync()}');
          }
          break;
      }
    }
  }

  Future<void> _cleanupCache() async {
    await _sharing.cleanupTempFiles();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming shares'),
        actions: [
          IconButton(
            onPressed: _cleanupCache,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: _payload == null
          ? const Center(child: Text('No shared content yet'))
          : ListView.builder(
              itemCount: _payload!.items.length,
              itemBuilder: (context, index) {
                final item = _payload!.items[index];
                return ListTile(
                  title: Text(item.fileName ?? item.content),
                  subtitle: Text('${item.type.name} | ${item.mimeType}'),
                );
              },
            ),
    );
  }
}
```

## System share-menu setup

### 1. macOS (Finder Share sheet, Services menu, and Dock drop)

macOS exposes three system entry points, each backed by a different mechanism:

1. **Finder Share sheet** (the same list as AirDrop, Send to WeChat, and Send to QQ): requires an embedded **macOS Share Extension** (`com.apple.share-services` `.appex`).
2. **Finder Services menu**: declared with `NSServices` in the host app `Info.plist`. This plugin already registers `NSApplication.shared.servicesProvider` and handles `handleSharingService`.
3. **Dropping a file on the Dock icon, or Open With**: declared with `CFBundleDocumentTypes` in the host app `Info.plist`, and delivered through `AppDelegate.application(_:open:)`.

The steps below wire up all three.

#### Step 1: Configure the host `macos/Runner/Info.plist`

Declare support for every file type (`CFBundleDocumentTypes`), the `acceptsharing` URL scheme used to wake the host app from the extension, and the Finder Services menu (`NSServices`):

```xml
<!-- 1. Accept any file dropped on the Dock icon, and Open With -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>All Files</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.item</string>
            <string>public.content</string>
            <string>public.data</string>
        </array>
    </dict>
</array>

<!-- 2. URL scheme the Share Extension uses to wake the host app -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>acceptsharing</string>
        </array>
    </dict>
</array>

<!-- 3. Finder Services context-menu item -->
<key>NSServices</key>
<array>
    <dict>
        <key>NSMenuItem</key>
        <dict>
            <key>default</key>
            <string>Send to Your App</string>
        </dict>
        <key>NSMessage</key>
        <string>handleSharingService</string>
        <key>NSPortName</key>
        <string>$(PRODUCT_NAME)</string>
        <key>NSSendFileTypes</key>
        <array>
            <string>public.item</string>
            <string>public.content</string>
            <string>public.data</string>
        </array>
        <key>NSSendTypes</key>
        <array>
            <string>NSFilenamesPboardType</string>
            <string>public.file-url</string>
            <string>public.utf8-plain-text</string>
        </array>
    </dict>
</array>
```

#### Step 2: Forward URLs from `macos/Runner/AppDelegate.swift`

```swift
import Cocoa
import FlutterMacOS
import xue_hua_navite_accept_sharing

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ application: NSApplication, open urls: [URL]) {
    XueHuaNaviteAcceptSharingPlugin.shared.handleOpen(urls)
  }
}
```

#### Step 3: Add a macOS Share Extension target (Finder Share sheet)

To show the app in the Finder Share sheet next to Send to WeChat and Send to QQ:

1. **Create a Share Extension target in Xcode**:
   - Open `macos/Runner.xcworkspace`.
   - Choose `File -> New -> Target...`, select **macOS -> Share Extension**, and name it `ShareExtension`.
   - On the host `Runner` target, make sure `Build Phases -> Embed App Extensions` (or `Copy Files` with Destination `PlugIns`) includes `ShareExtension.appex`.
2. **Configure `macos/ShareExtension/Info.plist`**:
   - Set `CFBundleDisplayName` to the name that should appear in the Share menu (for example `Send to Your App`).
   - In `NSExtensionActivationRule`, enable files, images, movies, web URLs, and text so the extension is offered for `.apk` files, archives, images, and videos alike:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>Send to Your App</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
	<key>CFBundleShortVersionString</key>
	<string>$(FLUTTER_BUILD_NAME)</string>
	<key>CFBundleVersion</key>
	<string>$(FLUTTER_BUILD_NUMBER)</string>
	<key>LSMinimumSystemVersion</key>
	<string>$(MACOSX_DEPLOYMENT_TARGET)</string>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionAttributes</key>
		<dict>
			<key>NSExtensionActivationRule</key>
			<dict>
				<key>NSExtensionActivationSupportsFileWithMaxCount</key>
				<integer>100</integer>
				<key>NSExtensionActivationSupportsImageWithMaxCount</key>
				<integer>100</integer>
				<key>NSExtensionActivationSupportsMovieWithMaxCount</key>
				<integer>100</integer>
				<key>NSExtensionActivationSupportsText</key>
				<true/>
				<key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
				<integer>100</integer>
			</dict>
		</dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.share-services</string>
		<key>NSExtensionPrincipalClass</key>
		<string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
	</dict>
</dict>
</plist>
```

3. **Sandbox entitlements**:
   - With an Apple Developer signing identity, enable the same **App Group** (for example `group.<host bundle id>`) on both `Runner` and `ShareExtension` under `Signing & Capabilities`.
   - For local ad-hoc builds without a certificate, also grant file read and shared temp-directory access in `macos/ShareExtension/ShareExtension.entitlements`, `macos/Runner/DebugProfile.entitlements`, and `Release.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
	<string>/tmp/</string>
	<string>/private/tmp/</string>
</array>
```

4. **`macos/ShareExtension/ShareViewController.swift`** (hand off to the host app with no extra sheet):
   This matches Send to WeChat: after the user picks the app in the Finder Share sheet, the extension copies every file, image, and video and launches the Flutter host app. It does not present an extra text editor.

```swift
import Cocoa
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: NSViewController {
  // Replace with group.<your host app bundle id>
  private let appGroupId = "group.com.yourcompany.yourapp"
  private let hostAppScheme = "acceptsharing://share"
  private let payloadKey = "xue_hua_shared_payload"

  override func loadView() {
    self.view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    handleSharedItems()
  }

  private func handleSharedItems() {
    guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem],
          !extensionItems.isEmpty else {
      completeRequest()
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var sharedItems: [[String: Any]] = []
    var sharedText: String?

    for item in extensionItems {
      if let text = item.attributedContentText?.string, !text.isEmpty {
        sharedText = text
      }
      guard let attachments = item.attachments else { continue }

      for provider in attachments {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
          group.enter()
          provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
            defer { group.leave() }
            if let url = Self.extractURL(from: data),
               let copied = self.stageSharedFile(url: url) {
              lock.lock()
              sharedItems.append(copied)
              lock.unlock()
            }
          }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          group.enter()
          provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
            defer { group.leave() }
            if let url = Self.extractURL(from: data) {
              if url.isFileURL, let copied = self.stageSharedFile(url: url) {
                lock.lock()
                sharedItems.append(copied)
                lock.unlock()
              } else {
                lock.lock()
                sharedItems.append([
                  "type": "url",
                  "content": url.absoluteString,
                  "mimeType": "text/uri-list",
                ])
                lock.unlock()
              }
            }
          }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          group.enter()
          provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            defer { group.leave() }
            if let text = data as? String, !text.isEmpty {
              lock.lock()
              if sharedText == nil { sharedText = text }
              sharedItems.append([
                "type": "text",
                "content": text,
                "mimeType": "text/plain",
              ])
              lock.unlock()
            }
          }
        } else if let typeId = provider.registeredTypeIdentifiers.first {
          group.enter()
          provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
            defer { group.leave() }
            if let url = url, let copied = self.stageSharedFile(url: url) {
              lock.lock()
              sharedItems.append(copied)
              lock.unlock()
            }
          }
        }
      }
    }

    group.notify(queue: .main) {
      var payload: [String: Any] = ["items": sharedItems]
      if let text = sharedText {
        payload["text"] = text
      }

      // 1. Write App Group UserDefaults (distribution builds with a real signing identity).
      if let defaults = UserDefaults(suiteName: self.appGroupId) {
        defaults.set(payload, forKey: self.payloadKey)
        defaults.synchronize()
      }

      // 2. Also write a temp manifest and pass a Base64 payload in the URL query
      //    (local ad-hoc builds without a certificate).
      let fallbackDir = URL(fileURLWithPath: "/tmp/xue_hua_accept_sharing", isDirectory: true)
      try? FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
      if let jsonData = try? JSONSerialization.data(withJSONObject: payload) {
        let manifestURL = fallbackDir.appendingPathComponent("payload.json")
        try? jsonData.write(to: manifestURL)
        let base64 = jsonData.base64EncodedString()
        var comps = URLComponents(string: self.hostAppScheme)
        comps?.queryItems = [URLQueryItem(name: "payload", value: base64)]
        if let targetURL = comps?.url {
          NSWorkspace.shared.open(targetURL)
          self.completeRequest()
          return
        }
      }

      if let fallbackURL = URL(string: self.hostAppScheme) {
        NSWorkspace.shared.open(fallbackURL)
      }
      self.completeRequest()
    }
  }

  private static func extractURL(from data: NSSecureCoding?) -> URL? {
    if let url = data as? URL { return url }
    if let nsUrl = data as? NSURL { return nsUrl as URL }
    if let urlData = data as? Data {
      return URL(dataRepresentation: urlData, relativeTo: nil)
    }
    if let str = data as? String {
      return URL(string: str) ?? URL(fileURLWithPath: str)
    }
    return nil
  }

  private func stageSharedFile(url: URL) -> [String: Any]? {
    let hasScope = url.startAccessingSecurityScopedResource()
    defer {
      if hasScope { url.stopAccessingSecurityScopedResource() }
    }

    let baseDir: URL
    if let groupContainer = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) {
      baseDir = groupContainer.appendingPathComponent("shared_files", isDirectory: true)
    } else {
      baseDir = URL(fileURLWithPath: "/tmp/xue_hua_accept_sharing/shared_files", isDirectory: true)
    }

    try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    let fileName = url.lastPathComponent.isEmpty ? "shared_file" : url.lastPathComponent
    let destURL = baseDir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))_\(fileName)")
    try? FileManager.default.removeItem(at: destURL)

    let targetURL: URL
    if (try? FileManager.default.copyItem(at: url, to: destURL)) != nil {
      targetURL = destURL
    } else {
      targetURL = url
    }

    let size = (try? FileManager.default.attributesOfItem(atPath: targetURL.path)[.size] as? Int64) ?? 0
    let ext = targetURL.pathExtension
    let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    let type: String
    if mime.hasPrefix("image/") { type = "image" }
    else if mime.hasPrefix("video/") { type = "video" }
    else if mime.hasPrefix("audio/") { type = "audio" }
    else { type = "file" }

    return [
      "type": type,
      "content": targetURL.path,
      "fileName": fileName,
      "mimeType": mime,
      "fileSize": size,
    ]
  }

  private func completeRequest() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }
}
```

5. **Enable the extension in the macOS Share menu after the first build**:
   - Run `flutter run -d macos` once. `pluginkit` registers the embedded `ShareExtension.appex` automatically.
   - If the app does not appear immediately under Finder **Share...**, open **Edit Extensions...** at the bottom of the share sheet and enable the extension. It then stays in the list.

### 2. iOS (system Share Sheet and Open In)

#### Case A: Open In and AirDrop

1. **Declare every document type and the `acceptsharing` URL scheme in `ios/Runner/Info.plist`**:

```xml
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>All Files</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.item</string>
            <string>public.content</string>
            <string>public.data</string>
        </array>
    </dict>
</array>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>acceptsharing</string>
        </array>
    </dict>
</array>
```

2. **Forward URLs from `ios/Runner/SceneDelegate.swift`**:

```swift
import Flutter
import UIKit
import xue_hua_navite_accept_sharing

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    let urls = connectionOptions.urlContexts.map { $0.url }
    if !urls.isEmpty {
      XueHuaNaviteAcceptSharingPlugin.shared.handleOpenURLs(urls, isInitial: true)
    }
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    let urls = URLContexts.map { $0.url }
    if !urls.isEmpty {
      XueHuaNaviteAcceptSharingPlugin.shared.handleOpenURLs(urls, isInitial: false)
    }
  }
}
```

#### Case B: Appear in the system Share Sheet

1. **Create a Share Extension target**: open `ios/Runner.xcworkspace`, then `File -> New -> Target... -> Share Extension`, and name it `ShareExtension`.
2. **Configure an App Group**: enable the same App Group (for example `group.<host bundle id>`) on both `Runner` and `ShareExtension`.
3. **Set `NSExtensionActivationRule` in `ios/ShareExtension/Info.plist`**. Enable `NSExtensionActivationSupportsFileWithMaxCount`, plus image, movie, web URL, and text, as on macOS.
4. **In `ios/ShareExtension/ShareViewController.swift`**, copy attachments into the App Group and wake the host app with `acceptsharing://share`.

### 3. Android (system share sheet intent filters)

Add the following `<intent-filter>` blocks inside the main `MainActivity` in `android/app/src/main/AndroidManifest.xml`. `android:launchMode="singleTop"` is recommended:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>

    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- 1. Shared plain text and URLs -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/*" />
    </intent-filter>

    <!-- 2. A single file of any type -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="*/*" />
    </intent-filter>

    <!-- 3. Multiple files of any type -->
    <intent-filter>
        <action android:name="android.intent.action.SEND_MULTIPLE" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="*/*" />
    </intent-filter>

    <!-- 4. Open any file with this app from a file manager -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="content" />
        <data android:scheme="file" />
        <data android:mimeType="*/*" />
    </intent-filter>
</activity>
```

### 4. Windows (Send to, Open with, and single-instance WM_COPYDATA)

File Explorer's **Share** command only lists packaged **Share Targets**. An unpackaged process (`flutter run`, or a plain `.exe`) does not appear there. That is expected. Send files with **Send to**, **Open with**, or the right-click command instead. An MSIX Share Target is optional and is not required for this plugin.

The example registers those entries the first time its executable starts, and points them at that executable (the debug exe from `flutter run`, or an installed copy):

| Entry | Where it appears |
| --- | --- |
| **Send to → Xue Hua Accept Sharing Example** | File Explorer **Send to** (`shell:sendto`) |
| **Open with Xue Hua Accept Sharing Example** | File context menu. On Windows 11 it is under **Show more options** |
| **Open with** | Common types (images, text, audio, video, PDF, zip, and the other extensions registered by the example) |

Registration is per user (`HKCU` and `%APPDATA%\Microsoft\Windows\SendTo`). It does not replace the default app used when a file is double-clicked. A later launch of the same example forwards its arguments to the running window and exits, so quit the example before starting `flutter run` again.

- **Cold start**: Explorer starts the exe with the file paths. `getInitialSharing()` returns them.
- **Already running**: the new process sends `WM_COPYDATA` (`dwData = 0x58485348`, UTF-8 arguments separated by newlines) and exits. `onSharingReceived` emits the payload. Several selected files arrive in one payload (`MultiSelectModel = Player`, up to 100 files for this static verb).

```bash
cd example
flutter run -d windows
```

Right-click a file and choose **Send to → Xue Hua Accept Sharing Example**.

An optional installer, which still uses the same startup registration and does not add a Share Target:

```bash
cd example
fpack build exe
```

Run the `dist/*-windows-x64-setup.exe` produced by [fpack](https://pub.dev/packages/fpack) (`example/fpack.yaml`).

Copy `example/windows/runner/single_instance.*` and `example/windows/runner/explorer_registration.*` into your own runner and call them from `wWinMain` before the window is created. The forwarder finds `FLUTTER_RUNNER_WIN32_WINDOW` by your window title. The plugin ignores `WM_COPYDATA` unless `dwData` is `0x58485348`.

```cpp
if (ForwardToExistingInstance(command_line_arguments)) {
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
RegisterExplorerIntegration();
```

### 5. Linux (Open with and .desktop launcher)

Set `Exec=/path/to/your_app %U` and `MimeType` in `~/.local/share/applications/your_app.desktop`. GNOME and KDE file managers can then share or open files with the app from the context menu:

```ini
[Desktop Entry]
Name=Your Flutter App
Comment=Receive shared files and text
Exec=/path/to/your_app %U
Icon=your_app
Terminal=false
Type=Application
Categories=Utility;
MimeType=text/plain;image/*;video/*;audio/*;application/pdf;application/octet-stream;x-scheme-handler/http;x-scheme-handler/https;
```

### 6. Web (PWA) system share menu (Web Share Target API)

Declare `share_target` in `web/manifest.json`. A service worker intercepts `POST` `/_share_target` and forwards the body on `BroadcastChannel('xue_hua_navite_accept_sharing')`. After the PWA is installed, it can appear in the system share menu:

```json
{
  "name": "Your App",
  "short_name": "YourApp",
  "start_url": "/",
  "display": "standalone",
  "share_target": {
    "action": "/_share_target",
    "method": "POST",
    "enctype": "multipart/form-data",
    "params": {
      "title": "title",
      "text": "text",
      "url": "url",
      "files": [
        {
          "name": "files",
          "accept": ["*/*", "image/*", "video/*", "audio/*", "text/*", "application/*"]
        }
      ]
    }
  }
}
```
