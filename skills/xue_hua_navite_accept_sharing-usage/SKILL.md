---
name: xue_hua_navite_accept_sharing-usage
description: >-
  Use when the user is working with xue_hua_navite_accept_sharing APIs or
  configuring system Share Menu / Share Extension integration to receive shared
  text, URLs, images, videos, and arbitrary files across Android, iOS, macOS,
  Windows, Linux, and Web.
---

# XueHua Native Accept Sharing Usage & Share Menu Integration

## Guidelines

* Use `XueHuaNaviteAcceptSharing.instance` to access the singleton sharing receiver across all 6 platforms.
* Call `await XueHuaNaviteAcceptSharing.instance.getInitialSharing()` in `initState()` to retrieve any `SharedPayload` that launched the application on cold start, and immediately call `await XueHuaNaviteAcceptSharing.instance.clearInitialSharing()` after handling it.
* Subscribe to `XueHuaNaviteAcceptSharing.instance.onSharingReceived` to receive new `SharedPayload` events while the app is already running, and cancel the subscription in `dispose()`.
* Call `await XueHuaNaviteAcceptSharing.instance.cleanupTempFiles()` after copying or uploading shared files to remove temporary sandbox copies.
* When integrating the **system Share Menu (共享菜单)** on each platform, configure both the Dart listener and the platform-native Share Extension / Intent Filter / Services configuration described below.

## Dart Usage Example

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

class AcceptSharingPage extends StatefulWidget {
  const AcceptSharingPage({super.key});

  @override
  State<AcceptSharingPage> createState() => _AcceptSharingPageState();
}

class _AcceptSharingPageState extends State<AcceptSharingPage> {
  final XueHuaNaviteAcceptSharing _sharing = XueHuaNaviteAcceptSharing.instance;
  StreamSubscription<SharedPayload>? _subscription;
  SharedPayload? _latestPayload;

  @override
  void initState() {
    super.initState();
    _setupSharingReceiver();
  }

  Future<void> _setupSharingReceiver() async {
    final SharedPayload? initial = await _sharing.getInitialSharing();
    if (initial != null && initial.isNotEmpty) {
      _handlePayload(initial);
      await _sharing.clearInitialSharing();
    }
    _subscription = _sharing.onSharingReceived.listen(_handlePayload);
  }

  void _handlePayload(SharedPayload payload) {
    if (!mounted) return;
    setState(() {
      _latestPayload = payload;
    });
    for (final SharedMediaItem item in payload.items) {
      if (item.isFile) {
        final file = File(item.content);
        debugPrint('Shared file: ${item.fileName} (${item.fileSize} bytes) -> ${file.path}');
      } else {
        debugPrint('Shared text/URL: ${item.content}');
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _latestPayload?.items ?? const <SharedMediaItem>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Received Shared Items'),
        actions: <Widget>[
          IconButton(
            onPressed: _sharing.cleanupTempFiles,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) {
          final SharedMediaItem item = items[index];
          return ListTile(
            title: Text(item.fileName ?? item.content),
            subtitle: Text('${item.type.name} | ${item.mimeType ?? "unknown"}'),
          );
        },
      ),
    );
  }
}
```

## Platform Share Menu (共享菜单) Integration

### 1. macOS Share Menu Integration (Finder "共享..." Popover, Services Menu & Dock Drop)

On macOS, appearing in the Finder right-click **"共享..." (Share)** popover (alongside AirDrop, WeChat, QQ) requires embedding a **macOS Share Extension (`com.apple.share-services` `.appex`)** inside `Runner.app/Contents/PlugIns/`.

1. **Configure `macos/Runner/Info.plist`** (supports Dock drop / Open With via `CFBundleDocumentTypes`, URL wakeup via `acceptsharing`, and Finder Services menu via `NSServices`):

```xml
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
<key>NSServices</key>
<array>
	<dict>
		<key>NSMenuItem</key>
		<dict>
			<key>default</key>
			<string>Send to App</string>
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

2. **Forward URLs in `macos/Runner/AppDelegate.swift`**:

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

3. **Add a macOS `ShareExtension` Target in Xcode (`File -> New -> Target -> macOS -> Share Extension`)**:
   - Configure `macos/ShareExtension/Info.plist` with `com.apple.share-services` and `NSExtensionActivationRule` supporting files, images, movies, URLs, and text:

```xml
<key>CFBundleDisplayName</key>
<string>Send to YourApp</string>
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
```

   - In `macos/ShareExtension/ShareViewController.swift`, extract `NSExtensionItem` attachments, stage files to the App Group container (or `/tmp/xue_hua_accept_sharing/shared_files`), write the payload to `UserDefaults(suiteName:)` and `/tmp/xue_hua_accept_sharing/payload.json`, and open `acceptsharing://share?payload=<base64>` via `NSWorkspace.shared.open(targetURL)` before calling `extensionContext?.completeRequest(returningItems: [], completionHandler: nil)`.
   - Add `com.apple.security.files.user-selected.read-only` and `/tmp/` read-write exception to both `ShareExtension.entitlements` and `Runner/DebugProfile.entitlements` & `Release.entitlements`.

### 2. iOS Share Sheet & Open-In Integration

1. Add `CFBundleDocumentTypes` (`public.item`, `public.content`, `public.data`) and `CFBundleURLTypes` (`acceptsharing`) to `ios/Runner/Info.plist`.
2. Forward `connectionOptions.urlContexts` and `openURLContexts` to `XueHuaNaviteAcceptSharingPlugin.shared.handleOpenURLs(urls, isInitial: ...)` in `ios/Runner/SceneDelegate.swift`.
3. Create an iOS `ShareExtension` target sharing the same App Group (`group.<bundle_id>`), write shared items to `UserDefaults(suiteName: appGroupId)` under key `xue_hua_shared_payload`, and open `acceptsharing://share`.

### 3. Android Share Menu Integration

In `android/app/src/main/AndroidManifest.xml`, set `android:launchMode="singleTop"` on `MainActivity` and add `<intent-filter>` blocks for:
* `android.intent.action.SEND` with `mimeType="text/*"` and `mimeType="*/*"`
* `android.intent.action.SEND_MULTIPLE` with `mimeType="*/*"`
* `android.intent.action.VIEW` with `scheme="content"` / `scheme="file"` and `mimeType="*/*"`

### 4. Windows, Linux & Web Share Menu Integration

* **Windows**: Add a shortcut to `shell:sendto` (`%APPDATA%\Microsoft\Windows\SendTo`) for right-click "Send to" menu support, and forward `WM_COPYDATA` (`dwData = 0x58485348`) in `windows/runner/main.cpp` for single-instance warm-start sharing.
* **Linux**: Configure `Exec=/path/to/app %U` and `MimeType=...` in `~/.local/share/applications/<app>.desktop`.
* **Web (PWA)**: Add `share_target` (`method: "POST"`, `enctype: "multipart/form-data"`) to `web/manifest.json` and forward multipart form data in the Service Worker via `BroadcastChannel('xue_hua_navite_accept_sharing')`.
