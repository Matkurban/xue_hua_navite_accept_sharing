# xue_hua_navite_accept_sharing

[English](README.md)

跨平台 Flutter 接收分享插件，支持在 **Android、iOS、macOS、Windows、Linux、Web (PWA)** 全平台接收来自系统或其他应用分享的 **纯文本、URL 链接以及任意类型的单文件/多文件**（图片、视频、音频、PDF、压缩包、Office 文档、APK、二进制文件等），同时支持**冷启动（应用未启动时通过分享拉起）**与**热启动（应用已在后台/前台运行时实时接收）**。

## 目录

1. [功能特性](#一功能特性)
2. [数据模型与核心 API](#二数据模型与核心-api)
3. [Dart 完整代码示例](#三dart-完整代码示例)
4. [各平台系统“共享菜单”配置与集成详解](#四各平台系统共享菜单配置与集成详解)
   - [1. macOS 共享菜单集成（Finder 右键“共享...”弹窗、服务菜单与 Dock 拖入）](#1-macos-共享菜单集成finder-右键共享弹窗服务菜单与-dock-拖入)
   - [2. iOS 共享菜单集成（系统 Share Sheet 分享面板与 Open In）](#2-ios-共享菜单集成系统-share-sheet-分享面板与-open-in)
   - [3. Android 共享菜单集成（系统分享面板 Intent Filter）](#3-android-共享菜单集成系统分享面板-intent-filter)
   - [4. Windows 共享与打开方式集成（右键“发送到”、打开方式与单实例 WM_COPYDATA）](#4-windows-共享与打开方式集成右键发送到打开方式与单实例-wm_copydata)
   - [5. Linux 打开方式与共享集成（.desktop 启动器配置）](#5-linux-打开方式与共享集成desktop-启动器配置)
   - [6. Web (PWA) 系统共享菜单集成（Web Share Target API）](#6-web-pwa-系统共享菜单集成web-share-target-api)

## 一、功能特性

| 平台          |                   文本 / URL 分享                   |                  单文件 / 多文件（任意类型）                  | 冷启动接收 (`getInitialSharing`) |   运行时实时流 (`onSharingReceived`)    |   临时文件清理 (`cleanupTempFiles`)   |
|:--------------|:---------------------------------------------------:|:-------------------------------------------------------------:|:--------------------------------:|:---------------------------------------:|:-------------------------------------:|
| **Android**   |                支持 (`ACTION_SEND`)                 |        支持 (`ACTION_SEND` / `SEND_MULTIPLE` / `VIEW`)        |               支持               |          支持 (`onNewIntent`)           | 支持（清理 `cacheDir/shared_files`）  |
| **iOS**       |        支持（Share Extension / URL Scheme）         |          支持（Open In / AirDrop / Share Extension）          |               支持               |                  支持                   | 支持（清理临时目录与 App Group 容器） |
| **macOS**     | 支持（Share Extension / `NSServices` / URL Scheme） | 支持（Finder“共享...”菜单 / 打开方式 / Dock 拖入 / 服务菜单） |               支持               |                  支持                   | 支持（清理临时目录与 App Group 容器） |
| **Windows**   |        支持（`--text` 参数 / `WM_COPYDATA`）        |      支持（打开方式 / 发送到 / 命令行 / `WM_COPYDATA`）       |               支持               |          支持（`WM_COPYDATA`）          |                 支持                  |
| **Linux**     |                支持（`--text` 参数）                |            支持（`.desktop` 打开方式 `%F` / `%U`）            |               支持               |                  支持                   |                 支持                  |
| **Web (PWA)** |           支持（`share_target` GET/POST）           |         支持（`share_target` POST + Service Worker）          |               支持               | 支持（`BroadcastChannel` / SW Message） |    支持（释放 `Blob Object URL`）     |

## 二、数据模型与核心 API

### 1. `SharedItemType`（分享项类型枚举）

- `SharedItemType.text`：纯文本内容
- `SharedItemType.url`：`http://` 或 `https://` 链接
- `SharedItemType.image`：图片文件（`image/*`）
- `SharedItemType.video`：视频文件（`video/*`）
- `SharedItemType.audio`：音频文件（`audio/*`）
- `SharedItemType.file`：其他任意类型文件（如 `application/pdf`、`application/zip`、`application/vnd.android.package-archive`、`application/octet-stream` 等）

### 2. `SharedMediaItem`（单项分享数据）

- `type` (`SharedItemType`)：自动识别的分享项类型
- `content` (`String`)：当 `isFile == true` 时为本地文件绝对路径（Web 端为 `Blob URL`）；当为文本或链接时为文本/URL 字符串本身
- `fileName` (`String?`)：原始文件名（含扩展名）
- `mimeType` (`String?`)：检测到的 MIME 类型
- `fileSize` (`int?`)：文件字节大小
- `bytes` (`Uint8List?`)：可选内存字节数据（Web 端或内存直传场景）
- `extra` (`Map<String, dynamic>?`)：扩展字段（如 `subject` 分享标题）
- `isFile` (`bool`)：便捷判断当前项是否为文件/媒体资源

### 3. `SharedPayload`（单次分享批次载荷）

- `items` (`List<SharedMediaItem>`)：本次分享包含的所有项目列表
- `files` (`List<SharedMediaItem>`)：仅筛选出文件/媒体项的便捷列表
- `textItems` (`List<SharedMediaItem>`)：仅筛选出纯文本/URL 项的便捷列表
- `text` (`String?`)：分享附带的文本内容或描述
- `subject` (`String?`)：分享主题/标题（如 Android `Intent.EXTRA_SUBJECT`）

### 4. `XueHuaNaviteAcceptSharing`（核心方法）

- `Future<SharedPayload?> getInitialSharing()`：获取冷启动拉起应用时的分享载荷
- `Stream<SharedPayload> get onSharingReceived`：监听应用运行期间新接收到的分享载荷流
- `Future<void> clearInitialSharing()`：清除已消费的冷启动分享缓存，防止页面重建或热重载时重复处理
- `Future<void> cleanupTempFiles()`：删除插件在沙盒缓存目录中创建的临时分享文件副本，释放磁盘空间

## 三、Dart 完整代码示例

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
    // 1. 获取冷启动时传入的分享内容
    final initial = await _sharing.getInitialSharing();
    if (initial != null && initial.isNotEmpty) {
      _handlePayload(initial);
      // 消费后立即清空冷启动缓存，避免重复触发
      await _sharing.clearInitialSharing();
    }

    // 2. 监听应用在后台/前台运行时新接收到的分享内容
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
          debugPrint('收到文本/链接: ${item.content}');
          break;
        case SharedItemType.image:
        case SharedItemType.video:
        case SharedItemType.audio:
        case SharedItemType.file:
          debugPrint(
            '收到文件: ${item.fileName}, MIME: ${item.mimeType}, '
            '大小: ${item.fileSize} bytes, 路径: ${item.content}',
          );
          final file = File(item.content);
          if (file.existsSync()) {
            debugPrint('本地文件可读，长度: ${file.lengthSync()}');
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
        title: const Text('接收分享示例'),
        actions: [
          IconButton(
            onPressed: _cleanupCache,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
        ],
      ),
      body: _payload == null
          ? const Center(child: Text('暂无分享内容'))
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

## 四、各平台系统“共享菜单”配置与集成详解

### 1. macOS 共享菜单集成（Finder 右键“共享...”弹窗、服务菜单与 Dock 拖入）

在 macOS 中，系统级文件分享共有三种入口，分别对应不同的系统机制：
1. **Finder 右键“共享...”弹窗列表（与“隔空投送、发送到微信、发送到QQ”同级）**：必须通过内嵌 **macOS Share Extension (`com.apple.share-services` `.appex`)** 实现。
2. **Finder 右键“服务 (Services)”菜单**：通过主应用 `Info.plist` 中的 `NSServices` 实现（本插件已在原生层自动注册 `NSApplication.shared.servicesProvider` 处理 `handleSharingService`）。
3. **拖拽文件到 Dock 应用图标 / 右键“打开方式”**：通过主应用 `Info.plist` 中的 `CFBundleDocumentTypes` + `AppDelegate.application(_:open:)` 实现。

以下为同时集成上述三种入口的完整步骤：

#### 第一步：配置主应用 `macos/Runner/Info.plist`
在 `macos/Runner/Info.plist` 中声明支持打开所有类型文件（`CFBundleDocumentTypes`）、接收扩展唤醒的 URL Scheme（`acceptsharing`）以及 Finder 服务菜单（`NSServices`）：

```xml
<!-- 1. 支持拖拽任意文件到 Dock 图标及右键“打开方式” -->
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

<!-- 2. 注册供 Share Extension 唤醒主应用的 URL Scheme -->
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

<!-- 3. 注册 Finder 右键“服务 (Services)”菜单项 -->
<key>NSServices</key>
<array>
    <dict>
        <key>NSMenuItem</key>
        <dict>
            <key>default</key>
            <string>发送到你的应用名称</string>
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

#### 第二步：在 `macos/Runner/AppDelegate.swift` 中转发 URL
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

#### 第三步：创建 macOS Share Extension Target（出现在 Finder“共享...”弹窗列表）
要让应用像“发送到微信”、“发送到QQ”一样出现在 Finder 右键“共享...”弹窗中：

1. **在 Xcode 中新建 Share Extension Target**：
   - 使用 Xcode 打开 `macos/Runner.xcworkspace`。
   - 点击菜单 `File -> New -> Target...`，选择 **macOS -> Share Extension**，命名为 `ShareExtension`。
   - 确保在主应用 `Runner` Target 的 `Build Phases -> Embed App Extensions`（或 `Copy Files` -> Destination `PlugIns`）中包含 `ShareExtension.appex`。
2. **配置 `macos/ShareExtension/Info.plist`**：
   - 设置 `CFBundleDisplayName` 为你在“共享”菜单中希望展示的名称（如 `发送到你的应用`）。
   - 在 `NSExtensionActivationRule` 中同时开启文件、图片、视频、网页链接与文本支持（这样无论是右键 `.apk`、压缩包、图片还是视频都能显示）：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>发送到你的应用名称</string>
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

3. **配置沙盒权限（Entitlements）**：
   - 若使用 Apple 开发者账号签名，可在 `Runner` 和 `ShareExtension` 的 `Signing & Capabilities` 中开启同一个 **App Groups**（例如 `group.<主应用 Bundle ID>`）。
   - 同时为支持本地无证书调试（Ad-hoc 签名），在 `macos/ShareExtension/ShareExtension.entitlements` 与 `macos/Runner/DebugProfile.entitlements`、`Release.entitlements` 中添加文件读取与共享临时目录权限：

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

4. **编写 `macos/ShareExtension/ShareViewController.swift`（无额外弹窗直达主应用）**：
   以下实现与“发送到微信”一致——用户在 Finder“共享...”菜单点击你的应用后，无需弹出多余的文本编辑框，直接提取所有文件/图片/视频并拉起 Flutter 主应用完成接收：

```swift
import Cocoa
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: NSViewController {
  // 替换为 group.<你的主应用 Bundle ID>
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

      // 1. 写入 App Group UserDefaults（正式签名环境）
      if let defaults = UserDefaults(suiteName: self.appGroupId) {
        defaults.set(payload, forKey: self.payloadKey)
        defaults.synchronize()
      }

      // 2. 同时写入临时清单并通过 URL Query 传递 Base64 载荷（兼容本地无证书 Ad-hoc 调试）
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

5. **首次编译后在 macOS“共享”菜单启用扩展**：
   - 运行 `flutter run -d macos` 启动一次应用后，macOS `pluginkit` 会自动注册内嵌的 `ShareExtension.appex`。
   - 若在 Finder 右键文件点击“共享...”未立即看到应用，点击分享弹窗底部的 **“编辑扩展... (Edit Extensions...)”**，勾选你的应用扩展即可固定显示在分享列表中。

### 2. iOS 共享菜单集成（系统 Share Sheet 分享面板与 Open In）

#### 场景 A：支持“用其他应用打开 (Open In)”与 AirDrop 直接接收文件

1. **在 `ios/Runner/Info.plist` 中声明支持任意文档类型与 `acceptsharing` URL Scheme**：

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

2. **在 `ios/Runner/SceneDelegate.swift` 中转发 URL**：

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

#### 场景 B：出现在 iOS 系统全局分享面板（Share Sheet）

1. **创建 Share Extension Target**：在 Xcode 中打开 `ios/Runner.xcworkspace`，选择 `File -> New -> Target... -> Share Extension`，命名为 `ShareExtension`。
2. **配置 App Groups**：为 `Runner` 和 `ShareExtension` 同时开启同一个 App Group（如 `group.<主应用 Bundle ID>`）。
3. **在 `ios/ShareExtension/Info.plist` 中配置 `NSExtensionActivationRule`**（同上开启 `NSExtensionActivationSupportsFileWithMaxCount`、`Image`、`Movie`、`WebURL`、`Text`）。
4. **在 `ios/ShareExtension/ShareViewController.swift` 中提取附件写入 App Group 并通过 `acceptsharing://share` 唤醒主应用**。

### 3. Android 共享菜单集成（系统分享面板 Intent Filter）

在 `android/app/src/main/AndroidManifest.xml` 的主 `MainActivity` 标签内添加以下 `<intent-filter>`（建议设置 `android:launchMode="singleTop"`）：

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

    <!-- 1. 接收分享的纯文本与 URL 链接 -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/*" />
    </intent-filter>

    <!-- 2. 接收任意类型的单个文件 -->
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="*/*" />
    </intent-filter>

    <!-- 3. 接收任意类型的多个文件 -->
    <intent-filter>
        <action android:name="android.intent.action.SEND_MULTIPLE" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="*/*" />
    </intent-filter>

    <!-- 4. 支持在系统文件管理器中选择“用本应用打开”任意文件 -->
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

### 4. Windows 共享与打开方式集成（右键“发送到”、打开方式与单实例 WM_COPYDATA）

资源管理器里的 **「共享」** 只列出已打包的 **Share Target**。`flutter run` 或普通 `.exe` 这种未打包进程不会出现在「共享」面板里，这是系统行为，不是注册漏了。日常把文件送进应用，用 **发送到**、**打开方式** 或右键命令即可。MSIX Share Target 是可选项，本插件不依赖它。

example 在自己的 exe 第一次启动时就会注册下面这些入口，并始终指向当前这份 exe（`flutter run` 的 Debug exe，或安装后的 exe）：

| 入口 | 出现位置 |
| --- | --- |
| **发送到 → Xue Hua Accept Sharing Example** | 资源管理器 **发送到**（`shell:sendto`） |
| **Open with Xue Hua Accept Sharing Example** | 文件右键菜单。Windows 11 在 **显示更多选项** 里 |
| **打开方式** | 常见类型（图片、文本、音频、视频、PDF、zip，以及 example 注册的其他扩展名） |

注册只写当前用户（`HKCU` 和 `%APPDATA%\Microsoft\Windows\SendTo`），不会抢走双击文件时的默认程序。example 已在运行时，再次启动会把参数转给已有窗口然后退出，所以重新 `flutter run` 之前先退出 example。

- **冷启动**：资源管理器带上文件路径启动 exe，`getInitialSharing()` 返回这些文件。
- **已经在运行**：新进程发送 `WM_COPYDATA`（`dwData = 0x58485348`，UTF-8 参数以换行分隔）后退出，`onSharingReceived` 收到载荷。多选文件会进同一次载荷（`MultiSelectModel = Player`，这种静态动词最多 100 个文件）。

```bash
cd example
flutter run -d windows
```

在资源管理器里右键文件，选择 **发送到 → Xue Hua Accept Sharing Example**。

可选安装包。安装后的 exe 同样在首次启动时注册上述入口，不会因此出现在「共享」面板：

```bash
cd example
fpack build exe
```

运行 [fpack](https://pub.dev/packages/fpack) 生成的 `dist/*-windows-x64-setup.exe`（配置见 `example/fpack.yaml`）。

把自己的 runner 接上时，复制 `example/windows/runner/single_instance.*` 和 `example/windows/runner/explorer_registration.*`，在 `wWinMain` 创建窗口之前调用。转发按窗口标题查找 `FLUTTER_RUNNER_WIN32_WINDOW`。`dwData` 不是 `0x58485348` 的 `WM_COPYDATA` 会被插件忽略。

```cpp
if (ForwardToExistingInstance(command_line_arguments)) {
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
RegisterExplorerIntegration();
```

### 5. Linux 打开方式与共享集成（`.desktop` 启动器配置）

在 `~/.local/share/applications/your_app.desktop` 中配置 `Exec=/path/to/your_app %U` 与 `MimeType`，即可在 GNOME/KDE 文件管理器右键菜单中将文件分享/发送到应用：

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

**冷启动：** Linux 插件从 `/proc/self/cmdline` 解析 `--text <value>`、`http(s)://` URL、`file://` URI 与普通文件路径，并通过 `getInitialSharing()` 暴露。

**热启动：** 宿主需注册带 `G_APPLICATION_HANDLES_COMMAND_LINE` 的**单实例** `GtkApplication`（参见 `example/linux/runner/my_application.cc`）。之后的“打开方式”/`.desktop` 激活应调用 `xue_hua_navite_accept_sharing_plugin_dispatch_arguments()`，以便运行中的实例在 `onSharingReceived` 上发出事件。若宿主保持多实例，则每次打开都会新起进程，仅冷启动生效。Linux 上 `cleanupTempFiles()` 为空操作，因为分享使用原始路径而非缓存副本。


### 6. Web (PWA) 系统共享菜单集成（Web Share Target API）

在 `web/manifest.json` 中配置 `share_target`，并配合 Service Worker 拦截 `/_share_target` `POST` 请求通过 `BroadcastChannel('xue_hua_navite_accept_sharing')` 转发，即可在安装 PWA 后出现在系统分享菜单中：

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
