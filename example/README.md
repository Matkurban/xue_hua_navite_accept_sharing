# xue_hua_navite_accept_sharing_example

Demonstrates how to use the xue_hua_navite_accept_sharing plugin.

## Windows File Explorer

`flutter run -d windows` does not show up under File Explorer **Share**. That menu only lists packaged Share Targets. After this example's exe starts, it registers entries that do work for an unpackaged build:

1. **Send to → Xue Hua Accept Sharing Example** (`shell:sendto`, also **发送到**).
2. **Open with Xue Hua Accept Sharing Example** on the file context menu (Windows 11: **Show more options** / **显示更多选项**).
3. **Open with** / **打开方式** for common file types.

The shortcut and the menu command point at the exe that just started, including a debug exe. If the example is already open, the new process forwards the files with `WM_COPYDATA` (`0x58485348`) and exits. A cold start delivers them through `getInitialSharing()`; a running window delivers them through `onSharingReceived`. Quit the example before launching `flutter run` again.

```bash
cd example
flutter run -d windows
```

Right-click one or more files and choose **Send to → Xue Hua Accept Sharing Example**.

Optional installer (still no Share Target; the installed exe registers the same entries on first launch):

```bash
cd example
fpack build exe
```

Run `dist/*-windows-x64-setup.exe`. Configuration: `fpack.yaml`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Linux integration tests (flutter drive)

From this `example/` directory (needs a display / `xvfb-run`):

```bash
# Basic UI + API
flutter drive -d linux \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/plugin_integration_test.dart

# Cold start with shared text
flutter drive -d linux \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/cold_start_share_test.dart \
  -a '--text' -a 'E2E_SHARE_TEXT_MARKER'

# Cold start with a file path
flutter drive -d linux \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/cold_start_file_test.dart \
  -a '/tmp/share_test_assets/hello.txt'

# Warm start (unique-instance second process)
flutter drive -d linux \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/warm_start_share_test.dart
```

Native Linux parser unit tests are built with the example and live at
`build/linux/x64/debug/plugins/xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_test`.


## macOS integration tests (flutter drive)

From this `example/` directory:

```bash
# Prepare shared file fixtures (real /tmp — sandboxed Directory.systemTemp differs)
mkdir -p /tmp/share_test_assets
echo hello > /tmp/share_test_assets/hello.txt
echo second > /tmp/share_test_assets/second.txt

# Basic UI + API
flutter drive -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/plugin_integration_test.dart

# Cold start with shared text (plugin reads ProcessInfo --text)
flutter drive -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/cold_start_share_test.dart \
  -a '--text' -a 'E2E_SHARE_TEXT_MARKER'

# Cold start with a file path (Open With / argv parity)
flutter drive -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/cold_start_file_test.dart \
  -a /tmp/share_test_assets/hello.txt

# Cold start URL classified as url
flutter drive -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/cold_start_url_test.dart \
  -a '--text' -a 'https://example.com/e2e'

# Cold start multiple files
flutter drive -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/cold_start_multi_file_test.dart \
  -a /tmp/share_test_assets/hello.txt -a /tmp/share_test_assets/second.txt

# Warm start (URL-scheme Share Extension handoff + Open With while running)
flutter drive -d macos \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/warm_start_share_test.dart
```

Share Extension / Finder Services still need a signed App Group for the
UserDefaults path; local ad-hoc builds use `/tmp/xue_hua_accept_sharing/payload.json`
plus `acceptsharing://share?payload=...` (covered by the warm-start suite).
macOS has no single-instance `--text` forwarder like Linux/Windows; a second
`open` of the `.app` may start another process unless Launch Services reuses
the running instance for document/URL opens.
