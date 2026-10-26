import Flutter
import UIKit
import UniformTypeIdentifiers

public class XueHuaNaviteAcceptSharingPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static let shared = XueHuaNaviteAcceptSharingPlugin()

  public static let methodChannelName = "xue_hua_navite_accept_sharing"
  public static let eventChannelName = "xue_hua_navite_accept_sharing/events"
  public static let sharedPayloadKey = "xue_hua_shared_payload"
  public static let sharedCacheDirName = "shared_files"

  private var eventSink: FlutterEventSink?
  internal var initialPayload: [String: Any?]?
  private var pendingStreamPayloads: [[String: Any?]] = []
  private var hasLaunched = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = XueHuaNaviteAcceptSharingPlugin.shared
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    registrar.addApplicationDelegate(instance)

    NotificationCenter.default.addObserver(
      instance,
      selector: #selector(instance.onAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    // Check if an App Group payload was deposited prior to engine initialization.
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
    if !pendingStreamPayloads.isEmpty {
      let queued = pendingStreamPayloads
      pendingStreamPayloads.removeAll()
      DispatchQueue.main.async {
        for item in queued {
          events(item)
        }
      }
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  @objc private func onAppDidBecomeActive() {
    checkAppGroupPayload(isInitial: !hasLaunched)
  }

  // MARK: - UIApplicationDelegate URL Handling

  public func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [AnyHashable: Any] = [:]
  ) -> Bool {
    if let url = launchOptions[UIApplication.LaunchOptionsKey.url] as? URL {
      _ = handleOpenURLs([url], isInitial: true)
    }
    checkAppGroupPayload(isInitial: true)
    return true
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return handleOpenURLs([url], isInitial: !hasLaunched)
  }

  /// Public entry point that can also be called from `SceneDelegate.scene(_:openURLContexts:)`
  /// when using `UISceneDelegate` / `FlutterSceneDelegate`.
  @discardableResult
  public func handleOpenURLs(_ urls: [URL], isInitial: Bool = false) -> Bool {
    var handledItems: [[String: Any?]] = []

    for url in urls {
      if isCustomShareScheme(url) {
        checkAppGroupPayload(isInitial: isInitial)
        return true
      }

      if url.isFileURL {
        if let item = resolveFileURL(url) {
          handledItems.append(item)
        }
      } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
        handledItems.append([
          "type": "url",
          "content": url.absoluteString,
          "mimeType": "text/uri-list",
        ])
      } else {
        // Check if URL query contains shared text/url parameters
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems, !queryItems.isEmpty {
          let text = queryItems.first(where: { $0.name == "text" })?.value
          let sharedUrl = queryItems.first(where: { $0.name == "url" })?.value
          let subject = queryItems.first(where: { $0.name == "subject" || $0.name == "title" })?.value
          if let sharedUrl = sharedUrl, !sharedUrl.isEmpty {
            handledItems.append([
              "type": "url",
              "content": sharedUrl,
              "mimeType": "text/uri-list",
              "extra": subject != nil ? ["subject": subject!] : nil,
            ])
          }
          if let text = text, !text.isEmpty {
            handledItems.append(buildTextItem(text, subject: subject))
          }
        }
      }
    }

    guard !handledItems.isEmpty else {
      return false
    }

    let payload: [String: Any?] = [
      "items": handledItems,
      "text": nil,
      "subject": nil,
    ]
    deliverPayload(payload, isInitial: isInitial)
    return true
  }

  // MARK: - App Group Share Extension Support

  public func resolveAppGroupId() -> String {
    if let configured = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
       !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return configured.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    let bundleId = Bundle.main.bundleIdentifier ?? "com.example.app"
    return "group.\(bundleId)"
  }

  private func isCustomShareScheme(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme.hasPrefix("acceptsharing")
  }

  public func checkAppGroupPayload(isInitial: Bool) {
    let appGroupId = resolveAppGroupId()
    guard let userDefaults = UserDefaults(suiteName: appGroupId),
          let rawPayload = userDefaults.dictionary(forKey: Self.sharedPayloadKey) else {
      return
    }

    userDefaults.removeObject(forKey: Self.sharedPayloadKey)
    userDefaults.synchronize()

    var payload: [String: Any?] = [:]
    for (k, v) in rawPayload {
      payload[k] = v
    }
    deliverPayload(payload, isInitial: isInitial)
  }

  private func clearAppGroupPayload() {
    let appGroupId = resolveAppGroupId()
    guard let userDefaults = UserDefaults(suiteName: appGroupId) else { return }
    userDefaults.removeObject(forKey: Self.sharedPayloadKey)
    userDefaults.synchronize()
  }

  internal func deliverPayload(_ payload: [String: Any?], isInitial: Bool) {
    if isInitial && !hasLaunched {
      // Multiple cold-start openURL / document callbacks can arrive one-by-one.
      if let existing = initialPayload {
        initialPayload = Self.mergePayloads(existing, payload)
      } else {
        initialPayload = payload
      }
    } else {
      if initialPayload == nil && !hasLaunched {
        initialPayload = payload
      }
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        if let sink = self.eventSink {
          sink(payload)
        } else {
          self.pendingStreamPayloads.append(payload)
        }
      }
    }
  }

  /// Merges two payloads by appending items and de-duplicating on `content`.
  internal static func mergePayloads(
    _ left: [String: Any?],
    _ right: [String: Any?]
  ) -> [String: Any?] {
    var items: [[String: Any?]] = []
    if let leftItems = left["items"] as? [[String: Any?]] {
      items.append(contentsOf: leftItems)
    } else if let leftItems = left["items"] as? [[String: Any]] {
      items.append(contentsOf: leftItems.map { dict in
        var out: [String: Any?] = [:]
        for (k, v) in dict { out[k] = v }
        return out
      })
    }
    if let rightItems = right["items"] as? [[String: Any?]] {
      items.append(contentsOf: rightItems)
    } else if let rightItems = right["items"] as? [[String: Any]] {
      items.append(contentsOf: rightItems.map { dict in
        var out: [String: Any?] = [:]
        for (k, v) in dict { out[k] = v }
        return out
      })
    }

    var seen = Set<String>()
    var unique: [[String: Any?]] = []
    for item in items {
      let key = (item["content"] as? String) ?? String(describing: item)
      if seen.insert(key).inserted {
        unique.append(item)
      }
    }

    let text = (left["text"] as? String) ?? (right["text"] as? String)
    let subject = (left["subject"] as? String) ?? (right["subject"] as? String)
    return [
      "items": unique,
      "text": text,
      "subject": subject,
    ]
  }

  // MARK: - File & Metadata Resolution

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
    let cacheDir = fileManager.temporaryDirectory.appendingPathComponent(
      Self.sharedCacheDirName,
      isDirectory: true
    )
    do {
      if !fileManager.fileExists(atPath: cacheDir.path) {
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
      }
      let fileName = url.lastPathComponent.isEmpty ? "shared_file" : url.lastPathComponent
      let destURL = cacheDir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))_\(fileName)")
      if fileManager.fileExists(atPath: destURL.path) {
        try fileManager.removeItem(at: destURL)
      }
      try fileManager.copyItem(at: url, to: destURL)

      let attrs = try? fileManager.attributesOfItem(atPath: destURL.path)
      let fileSize = attrs?[.size] as? Int64
      let mimeType = Self.detectMimeType(for: destURL)
      let itemType = Self.classifyMimeType(mimeType)

      return [
        "type": itemType,
        "content": destURL.path,
        "fileName": fileName,
        "mimeType": mimeType,
        "fileSize": fileSize,
      ]
    } catch {
      return nil
    }
  }

  public static func detectMimeType(for url: URL) -> String {
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
    var success = true
    if fileManager.fileExists(atPath: cacheDir.path) {
      do {
        try fileManager.removeItem(at: cacheDir)
      } catch {
        success = false
      }
    }

    let appGroupId = resolveAppGroupId()
    if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
      let groupSharedDir = groupURL.appendingPathComponent(Self.sharedCacheDirName, isDirectory: true)
      if fileManager.fileExists(atPath: groupSharedDir.path) {
        try? fileManager.removeItem(at: groupSharedDir)
      }
    }
    return success
  }
}
