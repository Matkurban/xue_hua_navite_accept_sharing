## 1.0.4

* Windows example: on startup, register Send to, a file context-menu command, and Open with for the current exe, and forward a later launch to the running window with `WM_COPYDATA`.
* Windows: ignore `WM_COPYDATA` unless `dwData` is `0x58485348`.

## 1.0.3

* Linux: support CMake 4 builds (bump googletest, CMake policy range).

## 1.0.2

* Windows: support CMake 4 / Visual Studio 2026 builds (bump googletest, CMake policy range, include `encodable_value.h`).

## 1.0.1

* Publish the package guide in English as `README.md`, and keep the Simplified Chinese guide as `README.zh-CN.md`.
* Lower the minimum Dart SDK constraint from `^3.13.5` to `^3.13.0`.

## 1.0.0

* Initial stable `1.0.0` release. Receives text, URLs, images, videos, audio, and arbitrary single or multiple files shared by the system or other apps on **Android, iOS, macOS, Windows, Linux, and Web (PWA)**.
* Supports cold-start delivery with `getInitialSharing`, and a live stream with `onSharingReceived` while the app is already running.
* Supports the macOS Share menu extension (Share Extension, `com.apple.share-services`), the Finder Services menu (`NSServices`), Open With, and dropping files onto the Dock icon.
* Provides `clearInitialSharing` to clear a consumed cold-start payload, and `cleanupTempFiles` to delete temporary shared-file copies.
* Ships an AI agent skill inside the package, following the official Dart layout (`skills/xue_hua_navite_accept_sharing-usage/SKILL.md`).
