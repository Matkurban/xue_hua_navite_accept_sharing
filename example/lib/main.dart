import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final XueHuaNaviteAcceptSharing _sharingPlugin =
      const XueHuaNaviteAcceptSharing();
  StreamSubscription<SharedPayload>? _subscription;
  SharedPayload? _latestPayload;
  String _statusMessage = 'Waiting for shared text or files...';

  @override
  void initState() {
    super.initState();
    _initSharingListener();
  }

  Future<void> _initSharingListener() async {
    try {
      // Plugin waits for native cold-start extract; retry briefly for slow file copies.
      SharedPayload? initial;
      for (var i = 0; i < 10; i++) {
        initial = await _sharingPlugin.getInitialSharing();
        if (initial != null && initial.isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final coldStart = initial;
      if (coldStart != null && coldStart.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _latestPayload = coldStart;
          _statusMessage =
              'Received initial sharing (${coldStart.items.length} item(s))';
        });
        await _sharingPlugin.clearInitialSharing();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to fetch initial sharing: $e';
      });
    }

    _subscription = _sharingPlugin.onSharingReceived.listen(
      (payload) {
        if (!mounted) return;
        setState(() {
          _latestPayload = payload;
          _statusMessage =
              'Received real-time sharing (${payload.items.length} item(s))';
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Sharing stream error: $error';
        });
      },
    );
  }

  Future<void> _clearAndCleanup() async {
    await _sharingPlugin.clearInitialSharing();
    await _sharingPlugin.cleanupTempFiles();
    if (!mounted) return;
    setState(() {
      _latestPayload = null;
      _statusMessage = 'Cleared shared data and cleaned up temporary files.';
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = _latestPayload;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Accept Sharing Example'),
          actions: <Widget>[
            IconButton(
              key: const Key('clearCleanupButton'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear & Cleanup Temp Files',
              onPressed: _clearAndCleanup,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Status: $_statusMessage',
                key: const Key('statusText'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (payload?.subject != null) ...<Widget>[
                Text('Subject: ${payload!.subject}'),
                const SizedBox(height: 4),
              ],
              if (payload?.text != null) ...<Widget>[
                Text('Text: ${payload!.text}'),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: payload == null || payload.items.isEmpty
                    ? const Center(
                        child: Text(
                          key: Key('emptyHint'),
                          'Share any text, link, image, video, audio, or file '
                          'from another app to this app to inspect it here.\n\n'
                          'Windows: right-click a file and use Send to → '
                          'Xue Hua Accept Sharing Example, Open with, or '
                          'Open with Xue Hua Accept Sharing Example. '
                          'The Share panel only lists packaged Share Targets.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: payload.items.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = payload.items[index];
                          return ListTile(
                            leading: Icon(_iconForType(item.type)),
                            title: Text(item.fileName ?? item.content),
                            subtitle: Text(
                              'Type: ${item.type.name} | '
                              'MIME: ${item.mimeType ?? "unknown"} | '
                              'Size: ${item.fileSize ?? "-"} bytes\n'
                              'Content: ${item.content}',
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(SharedItemType type) {
    switch (type) {
      case SharedItemType.text:
        return Icons.notes;
      case SharedItemType.url:
        return Icons.link;
      case SharedItemType.image:
        return Icons.image_outlined;
      case SharedItemType.video:
        return Icons.videocam_outlined;
      case SharedItemType.audio:
        return Icons.audiotrack_outlined;
      case SharedItemType.file:
        return Icons.insert_drive_file_outlined;
    }
  }
}
