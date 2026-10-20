import Cocoa
import UniformTypeIdentifiers

@objc(ShareViewController)
class ShareViewController: NSViewController {
  private let appGroupId = "group.com.kurban.xueHuaNaviteAcceptSharingExample"
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

      // 1. Save to App Group UserDefaults (when signed with App Group entitlements).
      if let defaults = UserDefaults(suiteName: self.appGroupId) {
        defaults.set(payload, forKey: self.payloadKey)
        defaults.synchronize()
      }

      // 2. Also write fallback manifest and pass base64 payload in URL query so
      // local/ad-hoc builds work immediately without paid provisioning profiles.
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
    if let url = data as? URL {
      return url
    }
    if let nsUrl = data as? NSURL {
      return nsUrl as URL
    }
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
      if hasScope {
        url.stopAccessingSecurityScopedResource()
      }
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
