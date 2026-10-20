import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

public class XueHuaNaviteAcceptSharingPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static let shared = XueHuaNaviteAcceptSharingPlugin()

  public static let methodChannelName = "xue_hua_navite_accept_sharing"
  public static let eventChannelName = "xue_hua_navite_accept_sharing/events"
  public static let sharedPayloadKey = "xue_hua_shared_payload"
  public static let sharedCacheDirName = "shared_files"

  private var eventSink: FlutterEventSink?
  internal var initialPayload: [String: Any?]?
  private var hasLaunched = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = XueHuaNaviteAcceptSharingPlugin.shared
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger
    )
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger
    )

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)

    // Register as macOS NSServices provider and refresh dynamic services so Finder
    // context menu and Services menu entries take effect immediately.
    NSApplication.shared.servicesProvider = instance
    NSUpdateDynamicServices()

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.onAppDidBecomeActive),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )

    instance.checkAppGroupPayload(isInitial: true)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getInitialSharing":
      checkAppGroupPayload(isInitial: true)
      hasLaunched = true
      result(initialPayload)
    case "clearInitialSharing":
      initialPayload = nil
      clearAppGroupPayload()
      result(nil)
    case "cleanupTempFiles":
      let ok = cleanupTemporaryFiles()
      if ok {
        result(nil)
      } else {
        result(
          FlutterError(
            code: "CLEANUP_ERROR",
            message: "Failed to clean up temporary shared files.",
            details: nil
          )
        )
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  @objc private func onAppDidBecomeActive() {
    checkAppGroupPayload(isInitial: !hasLaunched)
  }

  /// Handles macOS Finder context menu / "Services" (`NSServices`) pasteboard sharing.
  @objc public func handleSharingService(
    _ pboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    var items: [[String: Any?]] = []
    var sharedText: String?

    let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
    if let fileUrls = pboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
       !fileUrls.isEmpty {
      for fileUrl in fileUrls {
        if let item = resolveFileURL(fileUrl) {
          items.append(item)
        }
      }
    } else if let filenames = pboard.propertyList(
      forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
    ) as? [String] {
      for path in filenames {
        let fileUrl = URL(fileURLWithPath: path)
        if let item = resolveFileURL(fileUrl) {
          items.append(item)
        }
      }
    }

    if items.isEmpty, let str = pboard.string(forType: .string), !str.isEmpty {
      sharedText = str
      items.append(buildTextItem(str))
    }

    guard !items.isEmpty else { return }
    let payload: [String: Any?] = [
      "items": items,
      "text": sharedText,
      "subject": nil,
    ]
    NSApplication.shared.activate(ignoringOtherApps: true)
    deliverPayload(payload, isInitial: !hasLaunched)
  }

  /// Call this method from your macOS `AppDelegate.application(_:open:)` or
  /// `application(_:openFiles:)` to forward opened files and URLs to the plugin.
  @discardableResult
  public func handleOpen(_ urls: [URL], isInitial: Bool? = nil) -> Bool {
    let treatAsInitial = isInitial ?? !hasLaunched
    var items: [[String: Any?]] = []

    for url in urls {
      if let scheme = url.scheme?.lowercased(), scheme.hasPrefix("acceptsharing") {
        if let queryPayload = Self.decodePayloadFromURL(url) {
          deliverPayload(queryPayload, isInitial: treatAsInitial)
          clearAppGroupPayload()
          return true
        }
        checkAppGroupPayload(isInitial: treatAsInitial)
        return true
      }

      if url.isFileURL {
        if let item = resolveFileURL(url) {
          items.append(item)
        }
      } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
        items.append([
          "type": "url",
          "content": url.absoluteString,
          "mimeType": "text/uri-list",
        ])
      }
    }

    guard !items.isEmpty else {
      return false
    }

    let payload: [String: Any?] = [
      "items": items,
      "text": nil,
      "subject": nil,
    ]
    deliverPayload(payload, isInitial: treatAsInitial)
    return true
  }

  private static func decodePayloadFromURL(_ url: URL) -> [String: Any?]? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queryItems = components.queryItems,
          let base64Str = queryItems.first(where: { $0.name == "payload" })?.value,
          let data = Data(base64Encoded: base64Str),
          let jsonObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    var result: [String: Any?] = [:]
    for (k, v) in jsonObj {
      result[k] = v
    }
    return result
  }

  public func resolveAppGroupId() -> String {
    if let configured = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
       !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return configured.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let bundleId = Bundle.main.bundleIdentifier ?? "com.example.app"
    return "group.\(bundleId)"
  }

  public func checkAppGroupPayload(isInitial: Bool) {
    let appGroupId = resolveAppGroupId()
    if let userDefaults = UserDefaults(suiteName: appGroupId),
       let rawPayload = userDefaults.dictionary(forKey: Self.sharedPayloadKey) {
      userDefaults.removeObject(forKey: Self.sharedPayloadKey)
      userDefaults.synchronize()

      var payload: [String: Any?] = [:]
      for (k, v) in rawPayload {
        payload[k] = v
      }
      deliverPayload(payload, isInitial: isInitial)
      return
    }

    let sharedManifestURL = URL(fileURLWithPath: "/tmp/xue_hua_accept_sharing/payload.json")
    if FileManager.default.fileExists(atPath: sharedManifestURL.path),
       let data = try? Data(contentsOf: sharedManifestURL),
       let rawPayload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      try? FileManager.default.removeItem(at: sharedManifestURL)
      var payload: [String: Any?] = [:]
      for (k, v) in rawPayload {
        payload[k] = v
      }
      deliverPayload(payload, isInitial: isInitial)
    }
  }

  private func clearAppGroupPayload() {
    let appGroupId = resolveAppGroupId()
    if let userDefaults = UserDefaults(suiteName: appGroupId) {
      userDefaults.removeObject(forKey: Self.sharedPayloadKey)
      userDefaults.synchronize()
    }
    let sharedManifestURL = URL(fileURLWithPath: "/tmp/xue_hua_accept_sharing/payload.json")
    try? FileManager.default.removeItem(at: sharedManifestURL)
  }

  internal func deliverPayload(_ payload: [String: Any?], isInitial: Bool) {
    if isInitial && !hasLaunched {
      initialPayload = payload
    } else {
      if initialPayload == nil && !hasLaunched {
        initialPayload = payload
      }
      DispatchQueue.main.async { [weak self] in
        self?.eventSink?(payload)
      }
    }
  }

  internal func buildTextItem(_ text: String, subject: String? = nil) -> [String: Any?] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let isUrl = !trimmed.contains(" ") &&
      !trimmed.contains("\n") &&
      (trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://"))
    return [
      "type": isUrl ? "url" : "text",
      "content": text,
      "mimeType": isUrl ? "text/uri-list" : "text/plain",
      "extra": subject != nil ? ["subject": subject!] : nil,
    ]
  }

  private func resolveFileURL(_ url: URL) -> [String: Any?]? {
    let hasScope = url.startAccessingSecurityScopedResource()
    defer {
      if hasScope {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let fileManager = FileManager.default
    let fileName = url.lastPathComponent.isEmpty ? "shared_file" : url.lastPathComponent
    let attrs = try? fileManager.attributesOfItem(atPath: url.path)
    let fileSize = attrs?[.size] as? Int64
    let mimeType = Self.detectMimeType(for: url)
    let itemType = Self.classifyMimeType(mimeType)

    return [
      "type": itemType,
      "content": url.path,
      "fileName": fileName,
      "mimeType": mimeType,
      "fileSize": fileSize,
    ]
  }

  public static func detectMimeType(for url: URL) -> String {
    if #available(macOS 11.0, *) {
      if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
         let contentType = resourceValues.contentType,
         let mime = contentType.preferredMIMEType {
        return mime
      }
      let ext = url.pathExtension
      if !ext.isEmpty,
         let utType = UTType(filenameExtension: ext),
         let mime = utType.preferredMIMEType {
        return mime
      }
    }
    return "application/octet-stream"
  }

  public static func classifyMimeType(_ mimeType: String) -> String {
    let lower = mimeType.lowercased()
    if lower.hasPrefix("image/") { return "image" }
    if lower.hasPrefix("video/") { return "video" }
    if lower.hasPrefix("audio/") { return "audio" }
    return "file"
  }

  private func cleanupTemporaryFiles() -> Bool {
    let fileManager = FileManager.default
    let cacheDir = fileManager.temporaryDirectory.appendingPathComponent(
      Self.sharedCacheDirName,
      isDirectory: true
    )
    if fileManager.fileExists(atPath: cacheDir.path) {
      try? fileManager.removeItem(at: cacheDir)
    }
    let fallbackSharedDir = URL(fileURLWithPath: "/tmp/xue_hua_accept_sharing", isDirectory: true)
    if fileManager.fileExists(atPath: fallbackSharedDir.path) {
      try? fileManager.removeItem(at: fallbackSharedDir)
    }
    let appGroupId = resolveAppGroupId()
    if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
      let groupSharedDir = groupURL.appendingPathComponent(Self.sharedCacheDirName, isDirectory: true)
      if fileManager.fileExists(atPath: groupSharedDir.path) {
        try? fileManager.removeItem(at: groupSharedDir)
      }
    }
    return true
  }
}
