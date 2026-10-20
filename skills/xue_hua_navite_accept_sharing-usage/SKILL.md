---
name: xue_hua_navite_accept_sharing-usage
description: >-
  Use when the user is working with xue_hua_navite_accept_sharing APIs to
  receive shared text, URLs, images, videos, and arbitrary files across
  Android, iOS, macOS, Windows, Linux, and Web.
---

# XueHua Native Accept Sharing Usage

## Guidelines

* Use `XueHuaNaviteAcceptSharing.instance` to access the singleton sharing receiver across all 6 platforms.
* Call `await XueHuaNaviteAcceptSharing.instance.getInitialSharing()` in `initState()` to retrieve any `SharedPayload` that launched the application on cold start.
* Always call `await XueHuaNaviteAcceptSharing.instance.clearInitialSharing()` immediately after processing the initial payload so widget rebuilds or hot reloads do not re-trigger the same share action.
* Subscribe to `XueHuaNaviteAcceptSharing.instance.onSharingReceived` to receive new `SharedPayload` events while the app is running in the foreground or background, and cancel the `StreamSubscription` in `dispose()`.
* Call `await XueHuaNaviteAcceptSharing.instance.cleanupTempFiles()` after copying or uploading shared files to remove temporary sandbox copies.

## Examples

### Receiving cold-start and real-time shared files and text

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
