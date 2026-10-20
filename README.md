# xue_hua_navite_accept_sharing

跨平台 Flutter 接收分享插件，支持在 **Android、iOS、macOS、Windows、Linux、Web (PWA)** 全平台接收来自系统或其他应用分享的 **纯文本、URL 链接以及任意类型的单文件/多文件**（图片、视频、音频、PDF、压缩包、Office 文档、二进制文件等），同时支持**冷启动（应用未启动时通过分享拉起）**与**热启动（应用已在后台/前台运行时实时接收）**。

## 目录

1. [功能特性](#一功能特性)
2. [数据模型与核心 API](#二数据模型与核心-api)
3. [Dart 完整代码示例](#三dart-完整代码示例)
4. [各平台特殊配置与处理详解](#四各平台特殊配置与处理详解)
   - [Android 配置与特殊处理](#1-android-配置与特殊处理)
   - [iOS 配置与特殊处理（Open In 与 Share Extension）](#2-ios-配置与特殊处理open-in-与-share-extension)
   - [macOS 配置与特殊处理](#3-macos-配置与特殊处理)
   - [Windows 配置与特殊处理（命令行与单实例 WM_COPYDATA）](#4-windows-配置与特殊处理命令行与单实例-wm_copydata)
   - [Linux 配置与特殊处理（.desktop 启动器配置）](#5-linux-配置与特殊处理desktop-启动器配置)
   - [Web (PWA) 配置与特殊处理（Web Share Target API）](#6-web-pwa-配置与特殊处理web-share-target-api)

## 一、功能特性

| 平台          |            文本 / URL 分享            |            单文件 / 多文件（任意类型）             | 冷启动接收 (`getInitialSharing`) |   运行时实时流 (`onSharingReceived`)    |   临时文件清理 (`cleanupTempFiles`)   |
|:--------------|:-------------------------------------:|:--------------------------------------------------:|:--------------------------------:|:---------------------------------------:|:-------------------------------------:|
| **Android**   |         支持 (`ACTION_SEND`)          |  支持 (`ACTION_SEND` / `SEND_MULTIPLE` / `VIEW`)   |               支持               |          支持 (`onNewIntent`)           | 支持（清理 `cacheDir/shared_files`）  |
| **iOS**       | 支持（Share Extension / URL Scheme）  |    支持（Open In / AirDrop / Share Extension）     |               支持               |                  支持                   | 支持（清理临时目录与 App Group 容器） |
| **macOS**     | 支持（Share Extension / URL Scheme）  |   支持（打开方式 / Dock 拖入 / Share Extension）   |               支持               |                  支持                   | 支持（清理临时目录与 App Group 容器） |
| **Windows**   | 支持（`--text` 参数 / `WM_COPYDATA`） | 支持（打开方式 / 发送到 / 命令行 / `WM_COPYDATA`） |               支持               |          支持（`WM_COPYDATA`）          |                 支持                  |
| **Linux**     |         支持（`--text` 参数）         |      支持（`.desktop` 打开方式 `%F` / `%U`）       |               支持               |                  支持                   |                 支持                  |
| **Web (PWA)** |    支持（`share_target` GET/POST）    |    支持（`share_target` POST + Service Worker）    |               支持               | 支持（`BroadcastChannel` / SW Message） |    支持（释放 `Blob Object URL`）     |

## 二、数据模型与核心 API

### 1. `SharedItemType`（分享项类型枚举）

- `SharedItemType.text`：纯文本内容
- `SharedItemType.url`：`http://` 或 `https://` 链接
- `SharedItemType.image`：图片文件（`image/*`）
- `SharedItemType.video`：视频文件（`video/*`）
- `SharedItemType.audio`：音频文件（`audio/*`）
- `SharedItemType.file`：其他任意类型文件（如 `application/pdf`、`application/zip`、`application/octet-stream` 等）

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
          // 原生平台可直接使用 File(item.content) 读取或上传
          final file = File(item.content);
          if (file.existsSync()) {
            debugPrint('本地文件可读，长度: ${file.lengthSync()}');
          }
          break;
      }
    }
  }

  /// 处理完分享文件（如已上传或转存到业务目录）后清理临时缓存副本
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

## 四、各平台特殊配置与处理详解

### 1. Android 配置与特殊处理

#### 特殊处理机制说明
- **Scoped Storage 临时 URI 权限问题**：Android 10+ 中外部应用通过 `Intent.ACTION_SEND` 传递的 `content://` URI 仅具有临时读取权限，一旦 Activity 生命周期变化或异步延迟读取便会抛出 `SecurityException`。本插件在原生层通过 `ContentResolver` 自动读取文件名（`OpenableColumns.DISPLAY_NAME`）、大小（`OpenableColumns.SIZE`）与 MIME 类型，并在后台 IO 线程将文件流流式拷贝到应用私有缓存目录 `context.cacheDir/shared_files/`，向 Dart 层返回可直接通过 `File(item.content)` 访问的绝对路径。
- **`launchMode` 要求**：宿主 Activity 建议设置为 `android:launchMode="singleTop"`（或 `singleTask`），以确保应用已运行时从其他应用发起分享会触发 `onNewIntent` 并通过 `onSharingReceived` 实时推送，而不是重新创建多个 Activity 实例。

#### `android/app/src/main/AndroidManifest.xml` 配置示例
在主 `MainActivity` 标签内添加以下 `<intent-filter>`：

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>

    <!-- 原有 MAIN / LAUNCHER intent-filter -->
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

    <!-- 2. 接收任意类型的单个文件（图片、视频、音频、文档、压缩包等） -->
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

### 2. iOS 配置与特殊处理（Open In 与 Share Extension）

iOS 接收外部数据分为两种场景，可根据业务需求配置其中一种或同时配置两种：

#### 场景 A：支持“用其他应用打开 (Open In)”与 AirDrop 直接接收文件

1. **在 `ios/Runner/Info.plist` 中声明支持任意文档类型**：

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
```

2. **在 `ios/Runner/SceneDelegate.swift` 中转发 URL（适配 Flutter UISceneDelegate）**：
   插件会自动调用 `startAccessingSecurityScopedResource()` 将外部安全作用域文件拷贝到应用沙盒临时目录：

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

#### 场景 B：出现在系统全局分享面板（Share Sheet）接收文本、链接、相册图片/视频及任意文件

由于 iOS 沙盒机制限制，主应用必须通过 **Share Extension（分享扩展）+ App Group** 才能出现在 Safari、相册、备忘录及第三方 App 的系统分享菜单中：

1. **创建 Share Extension Target**：
   - 在 Xcode 中打开 `ios/Runner.xcworkspace`，选择 `File -> New -> Target... -> Share Extension`，命名为 `ShareExtension`。
2. **配置 App Groups**：
   - 在 Xcode 中选中主应用 `Runner` Target 和 `ShareExtension` Target，在 `Signing & Capabilities` 中均添加 **App Groups**，并勾选同一个 Group ID：默认规则为 `group.<主应用 Bundle ID>`（若使用自定义名称，可在 `Runner/Info.plist` 中设置 `<key>AppGroupId</key><string>group.your.custom.id</string>`）。
3. **在主应用 `ios/Runner/Info.plist` 中注册唤醒 URL Scheme**：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- 固定前缀 acceptsharing 即可被插件自动识别并读取 App Group 数据 -->
            <string>acceptsharing</string>
        </array>
    </dict>
</array>
```

4. **在 `ShareExtension/Info.plist` 中声明支持分享任意文件与文本**：

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionAttributes</key>
    <dict>
        <key>NSExtensionActivationRule</key>
        <dict>
            <key>NSExtensionActivationSupportsText</key>
            <true/>
            <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
            <integer>10</integer>
            <key>NSExtensionActivationSupportsImageWithMaxCount</key>
            <integer>50</integer>
            <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
            <integer>20</integer>
            <key>NSExtensionActivationSupportsFileWithMaxCount</key>
            <integer>50</integer>
        </dict>
    </dict>
    <key>NSExtensionMainStoryboard</key>
    <string>MainInterface</string>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
</dict>
```

5. **替换 `ShareExtension/ShareViewController.swift` 代码**：
   以下代码将分享的文本、URL 与任意类型文件写入 App Group 容器并自动拉起主应用，插件在主应用激活或被 URL 唤醒时会自动读取并推送到 Dart 层：

```swift
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
  // 请确保与 Runner 的 App Group ID 一致
  private let appGroupId = "group.com.yourcompany.yourapp"
  private let hostAppScheme = "acceptsharing://share"
  private let payloadKey = "xue_hua_shared_payload"

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    handleSharedItems()
  }

  private func handleSharedItems() {
    guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
      completeRequest()
      return
    }

    let group = DispatchGroup()
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
            if let url = data as? URL, let copied = self.copyToAppGroup(url: url) {
              sharedItems.append(copied)
            }
          }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          group.enter()
          provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
            defer { group.leave() }
            if let url = data as? URL {
              if url.isFileURL, let copied = self.copyToAppGroup(url: url) {
                sharedItems.append(copied)
              } else {
                sharedItems.append([
                  "type": "url",
                  "content": url.absoluteString,
                  "mimeType": "text/uri-list",
                ])
              }
            }
          }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          group.enter()
          provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
            defer { group.leave() }
            if let text = data as? String {
              sharedText = sharedText ?? text
              sharedItems.append([
                "type": "text",
                "content": text,
                "mimeType": "text/plain",
              ])
            }
          }
        } else if let typeId = provider.registeredTypeIdentifiers.first {
          group.enter()
          provider.loadFileRepresentation(forTypeIdentifier: typeId) { url, _ in
            defer { group.leave() }
            if let url = url, let copied = self.copyToAppGroup(url: url) {
              sharedItems.append(copied)
            }
          }
        }
      }
    }

    group.notify(queue: .main) {
      if let defaults = UserDefaults(suiteName: self.appGroupId) {
        let payload: [String: Any] = [
          "items": sharedItems,
          "text": sharedText as Any,
        ]
        defaults.set(payload, forKey: self.payloadKey)
        defaults.synchronize()
      }
      self.openHostApp()
      self.completeRequest()
    }
  }

  private func copyToAppGroup(url: URL) -> [String: Any]? {
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId
    ) else { return nil }

    let dir = containerURL.appendingPathComponent("shared_files", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let fileName = url.lastPathComponent.isEmpty ? "shared_file" : url.lastPathComponent
    let destURL = dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))_\(fileName)")
    try? FileManager.default.copyItem(at: url, to: destURL)

    let size = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
    let ext = destURL.pathExtension
    let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    let type: String
    if mime.hasPrefix("image/") { type = "image" }
    else if mime.hasPrefix("video/") { type = "video" }
    else if mime.hasPrefix("audio/") { type = "audio" }
    else { type = "file" }

    return [
      "type": type,
      "content": destURL.path,
      "fileName": fileName,
      "mimeType": mime,
      "fileSize": size,
    ]
  }

  private func openHostApp() {
    guard let url = URL(string: hostAppScheme) else { return }
    var responder: UIResponder? = self
    let selector = sel_registerName("openURL:")
    while let r = responder {
      if r.responds(to: selector) {
        r.perform(selector, with: url)
        break
      }
      responder = r.next
    }
  }

  private func completeRequest() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }
}
```

### 3. macOS 配置与特殊处理

#### 特殊处理机制说明
macOS 支持通过 Finder 右键“打开方式”、将任意文件拖拽到应用 Dock 图标打开，以及通过 macOS 系统 Share Extension（配合 App Group）接收分享。

1. **在 `macos/Runner/Info.plist` 中声明支持打开所有类型文件**：

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
```

2. **在 `macos/Runner/AppDelegate.swift` 中转发打开的文件/URL**：

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

### 4. Windows 配置与特殊处理（命令行与单实例 WM_COPYDATA）

#### 特殊处理机制说明
- **冷启动接收**：当用户通过 Windows 资源管理器右键“打开方式”、“发送到 (`shell:sendto`)”或命令行参数（如 `your_app.exe "C:\path\to\file.pdf"` 或 `your_app.exe --text "分享文本"`）启动应用时，插件自动调用 `GetCommandLineW` / `CommandLineToArgvW` 解析所有文件路径、URL 与文本参数，无需修改宿主代码即可通过 `getInitialSharing()` 获取。
- **运行中单实例实时接收 (`WM_COPYDATA`)**：Windows 默认每次右键“打开方式”会启动一个新的 `.exe` 进程。若希望应用已运行时不开启新窗口，而是将新分享的文件/文本实时推送给已运行实例的 `onSharingReceived` 流，可在 `windows/runner/main.cpp` 的 `wWinMain` 开头添加单实例检测与 `WM_COPYDATA` 转发（插件已在内部注册顶层窗口回调自动解析 `WM_COPYDATA`）：

```cpp
// 在 windows/runner/main.cpp 的 wWinMain 开头添加单实例转发：
HWND existing_window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"你的窗口标题");
if (existing_window != nullptr) {
  std::vector<std::string> args = GetCommandLineArguments();
  if (!args.empty()) {
    std::string joined;
    for (const auto& arg : args) {
      joined += arg + "\n";
    }
    COPYDATASTRUCT cds{};
    cds.dwData = 0x58485348; // 'XHSH'
    cds.cbData = static_cast<DWORD>(joined.size());
    cds.lpData = const_cast<char*>(joined.data());
    ::SendMessageW(existing_window, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds));
  }
  ::SetForegroundWindow(existing_window);
  return EXIT_SUCCESS;
}
```

### 5. Linux 配置与特殊处理（`.desktop` 启动器配置）

#### 特殊处理机制说明
Linux 桌面环境（GNOME、KDE 等）通过 `.desktop` 文件中的 `Exec` 占位符（`%F` 多文件路径或 `%U` 多 URI）向应用传递“打开方式/分享”的文件。插件会自动读取 `/proc/self/cmdline`，将 `file://` URI 转换为真实路径，并通过 GIO (`GFile` / `GFileInfo`) 检测准确的 MIME 类型和文件大小。

#### `.desktop` 配置文件示例 (`~/.local/share/applications/your_app.desktop`)

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

### 6. Web (PWA) 配置与特殊处理（Web Share Target API）

#### 特殊处理机制说明
在支持 Web Share Target API 的浏览器（如 Android Chrome、桌面 Chrome/Edge PWA）中，将 Web 应用安装为 PWA 后即可出现在系统分享菜单中：
1. **仅接收文本与链接（GET 模式）**：插件会自动解析页面 URL Query 参数中的 `title`、`text`、`url`。
2. **接收任意文件与文本（POST `multipart/form-data` 模式）**：由 Service Worker 拦截 `/_share_target` 的 `POST` 请求，并通过 `BroadcastChannel('xue_hua_navite_accept_sharing')` 或 `Client.postMessage` 将 `File`/`Blob` 转发给插件，插件自动生成 `Blob Object URL` 并填充文件元数据。

#### 1. `web/manifest.json` 配置示例

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

#### 2. Service Worker 拦截分享请求代码示例
在自定义 Service Worker 中添加如下拦截逻辑即可与本插件无缝对接：

```javascript
let pendingSharePayload = null;

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method === 'POST' && url.pathname.endsWith('/_share_target')) {
    event.respondWith((async () => {
      const formData = await event.request.formData();
      const title = formData.get('title') || '';
      const text = formData.get('text') || '';
      const sharedUrl = formData.get('url') || '';
      const files = formData.getAll('files');

      const items = [];
      for (const file of files) {
        if (file instanceof File) {
          items.push({
            blob: file,
            fileName: file.name,
            mimeType: file.type || 'application/octet-stream',
            fileSize: file.size,
          });
        }
      }
      if (sharedUrl) {
        items.push({ type: 'url', content: sharedUrl, mimeType: 'text/uri-list' });
      }

      pendingSharePayload = {
        channel: 'xue_hua_navite_accept_sharing',
        title,
        text: text || sharedUrl,
        items,
      };

      const bc = new BroadcastChannel('xue_hua_navite_accept_sharing');
      bc.postMessage(pendingSharePayload);
      bc.close();

      return Response.redirect('/?share_target=1', 303);
    })());
  }
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'xue_hua_request_initial_sharing' && pendingSharePayload) {
    event.source.postMessage(pendingSharePayload);
    pendingSharePayload = null;
  }
});
```
