import Cocoa
import FlutterMacOS
import xue_hua_navite_accept_sharing

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    XueHuaNaviteAcceptSharingPlugin.shared.handleOpen(urls)
  }
}
