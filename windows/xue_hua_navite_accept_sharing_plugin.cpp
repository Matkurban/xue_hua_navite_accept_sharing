#include "xue_hua_navite_accept_sharing_plugin.h"

#include <windows.h>
#include <shellapi.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace xue_hua_navite_accept_sharing {

namespace {

std::string WideToUtf8(const std::wstring &wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, wstr.data(),
                                        static_cast<int>(wstr.size()), nullptr,
                                        0, nullptr, nullptr);
  if (size_needed <= 0) return std::string();
  std::string result(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.data(), static_cast<int>(wstr.size()),
                      result.data(), size_needed, nullptr, nullptr);
  return result;
}

std::wstring Utf8ToWide(const std::string &str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, str.data(),
                                        static_cast<int>(str.size()), nullptr, 0);
  if (size_needed <= 0) return std::wstring();
  std::wstring result(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.data(), static_cast<int>(str.size()),
                      result.data(), size_needed);
  return result;
}

std::string ToLower(std::string s) {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

bool StartsWithIgnoreCase(const std::string &str, const std::string &prefix) {
  if (str.size() < prefix.size()) return false;
  return ToLower(str.substr(0, prefix.size())) == ToLower(prefix);
}

std::string DetectMimeTypeFromExtension(const std::string &ext_with_dot) {
  std::string ext = ToLower(ext_with_dot);
  if (ext == ".png") return "image/png";
  if (ext == ".jpg" || ext == ".jpeg") return "image/jpeg";
  if (ext == ".gif") return "image/gif";
  if (ext == ".webp") return "image/webp";
  if (ext == ".bmp") return "image/bmp";
  if (ext == ".svg") return "image/svg+xml";
  if (ext == ".mp4") return "video/mp4";
  if (ext == ".mov") return "video/quicktime";
  if (ext == ".mkv") return "video/x-matroska";
  if (ext == ".avi") return "video/x-msvideo";
  if (ext == ".webm") return "video/webm";
  if (ext == ".mp3") return "audio/mpeg";
  if (ext == ".wav") return "audio/wav";
  if (ext == ".ogg") return "audio/ogg";
  if (ext == ".m4a") return "audio/mp4";
  if (ext == ".flac") return "audio/flac";
  if (ext == ".pdf") return "application/pdf";
  if (ext == ".zip") return "application/zip";
  if (ext == ".json") return "application/json";
  if (ext == ".txt" || ext == ".md" || ext == ".csv" || ext == ".log") {
    return "text/plain";
  }
  return "application/octet-stream";
}

std::string ClassifyMimeType(const std::string &mime) {
  if (StartsWithIgnoreCase(mime, "image/")) return "image";
  if (StartsWithIgnoreCase(mime, "video/")) return "video";
  if (StartsWithIgnoreCase(mime, "audio/")) return "audio";
  return "file";
}

}  // namespace

// static
void XueHuaNaviteAcceptSharingPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto method_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_navite_accept_sharing",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "xue_hua_navite_accept_sharing/events",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<XueHuaNaviteAcceptSharingPlugin>(registrar);
  auto *plugin_pointer = plugin.get();

  method_channel->SetMethodCallHandler(
      [plugin_pointer](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer](
          const flutter::EncodableValue *arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->event_sink_ = std::move(events);
        return nullptr;
      },
      [plugin_pointer](const flutter::EncodableValue *arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->event_sink_.reset();
        return nullptr;
      });
  event_channel->SetStreamHandler(std::move(handler));

  registrar->AddPlugin(std::move(plugin));
}

XueHuaNaviteAcceptSharingPlugin::XueHuaNaviteAcceptSharingPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  ParseInitialCommandLine();
  if (registrar_ != nullptr) {
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleWindowProc(hwnd, message, wparam, lparam);
        });
  }
}

XueHuaNaviteAcceptSharingPlugin::~XueHuaNaviteAcceptSharingPlugin() {
  if (registrar_ != nullptr && window_proc_id_ != -1) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

void XueHuaNaviteAcceptSharingPlugin::ParseInitialCommandLine() {
  int argc = 0;
  wchar_t **argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return;
  }
  std::vector<std::string> args;
  // Skip argv[0] which is the executable path.
  for (int i = 1; i < argc; ++i) {
    std::string arg = WideToUtf8(argv[i]);
    if (!arg.empty()) {
      args.push_back(arg);
    }
  }
  ::LocalFree(argv);

  initial_payload_ = BuildPayloadFromArguments(args);
}

// static
std::optional<flutter::EncodableMap>
XueHuaNaviteAcceptSharingPlugin::BuildPayloadFromArguments(
    const std::vector<std::string> &args) {
  flutter::EncodableList items;
  std::string shared_text;

  for (size_t i = 0; i < args.size(); ++i) {
    const std::string &arg = args[i];
    if (arg.empty()) continue;

    // Ignore internal Flutter/Dart engine flags.
    if (StartsWithIgnoreCase(arg, "--dart-flags") ||
        StartsWithIgnoreCase(arg, "--observatory-port") ||
        StartsWithIgnoreCase(arg, "--vm-service-port") ||
        StartsWithIgnoreCase(arg, "--enable-dart-profiling") ||
        StartsWithIgnoreCase(arg, "--trace-startup")) {
      continue;
    }

    if (arg == "--text" && i + 1 < args.size()) {
      shared_text = args[++i];
      flutter::EncodableMap item;
      bool is_url = StartsWithIgnoreCase(shared_text, "http://") ||
                    StartsWithIgnoreCase(shared_text, "https://");
      item[flutter::EncodableValue("type")] =
          flutter::EncodableValue(is_url ? "url" : "text");
      item[flutter::EncodableValue("content")] =
          flutter::EncodableValue(shared_text);
      item[flutter::EncodableValue("mimeType")] =
          flutter::EncodableValue(is_url ? "text/uri-list" : "text/plain");
      items.push_back(flutter::EncodableValue(item));
      continue;
    }

    if (StartsWithIgnoreCase(arg, "http://") ||
        StartsWithIgnoreCase(arg, "https://")) {
      flutter::EncodableMap item;
      item[flutter::EncodableValue("type")] = flutter::EncodableValue("url");
      item[flutter::EncodableValue("content")] = flutter::EncodableValue(arg);
      item[flutter::EncodableValue("mimeType")] =
          flutter::EncodableValue("text/uri-list");
      items.push_back(flutter::EncodableValue(item));
      continue;
    }

    std::error_code ec;
    std::filesystem::path fs_path(Utf8ToWide(arg));
    if (std::filesystem::exists(fs_path, ec) &&
        !std::filesystem::is_directory(fs_path, ec)) {
      std::string file_name = WideToUtf8(fs_path.filename().wstring());
      std::string ext = WideToUtf8(fs_path.extension().wstring());
      std::string mime = DetectMimeTypeFromExtension(ext);
      std::string item_type = ClassifyMimeType(mime);
      auto file_size = std::filesystem::file_size(fs_path, ec);

      flutter::EncodableMap item;
      item[flutter::EncodableValue("type")] =
          flutter::EncodableValue(item_type);
      item[flutter::EncodableValue("content")] =
          flutter::EncodableValue(WideToUtf8(fs_path.wstring()));
      item[flutter::EncodableValue("fileName")] =
          flutter::EncodableValue(file_name);
      item[flutter::EncodableValue("mimeType")] =
          flutter::EncodableValue(mime);
      if (!ec) {
        item[flutter::EncodableValue("fileSize")] =
            flutter::EncodableValue(static_cast<int64_t>(file_size));
      }
      items.push_back(flutter::EncodableValue(item));
    } else if (!StartsWithIgnoreCase(arg, "-")) {
      // Treat non-flag argument as shared text if not a local file.
      if (shared_text.empty()) {
        shared_text = arg;
      }
      flutter::EncodableMap item;
      item[flutter::EncodableValue("type")] = flutter::EncodableValue("text");
      item[flutter::EncodableValue("content")] = flutter::EncodableValue(arg);
      item[flutter::EncodableValue("mimeType")] =
          flutter::EncodableValue("text/plain");
      items.push_back(flutter::EncodableValue(item));
    }
  }

  if (items.empty() && shared_text.empty()) {
    return std::nullopt;
  }

  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("items")] = flutter::EncodableValue(items);
  if (!shared_text.empty()) {
    payload[flutter::EncodableValue("text")] =
        flutter::EncodableValue(shared_text);
  }
  return payload;
}

std::optional<LRESULT> XueHuaNaviteAcceptSharingPlugin::HandleWindowProc(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_COPYDATA && lparam != 0) {
    const auto *cds = reinterpret_cast<const COPYDATASTRUCT *>(lparam);
    if (cds != nullptr && cds->cbData > 0 && cds->lpData != nullptr) {
      // Support UTF-8 newline-separated arguments sent via WM_COPYDATA.
      std::string raw( static_cast<const char *>(cds->lpData), cds->cbData);
      while (!raw.empty() && (raw.back() == '\0' || raw.back() == '\r' ||
                              raw.back() == '\n')) {
        raw.pop_back();
      }
      std::vector<std::string> args;
      size_t start = 0;
      while (start < raw.size()) {
        size_t end = raw.find('\n', start);
        std::string token =
            raw.substr(start, end == std::string::npos ? std::string::npos
                                                       : end - start);
        if (!token.empty() && token.back() == '\r') {
          token.pop_back();
        }
        if (!token.empty()) {
          args.push_back(token);
        }
        if (end == std::string::npos) break;
        start = end + 1;
      }

      auto payload = BuildPayloadFromArguments(args);
      if (payload.has_value()) {
        if (event_sink_) {
          event_sink_->Success(flutter::EncodableValue(*payload));
        } else {
          initial_payload_ = payload;
        }
        return 1;
      }
    }
  }
  return std::nullopt;
}

void XueHuaNaviteAcceptSharingPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  if (method == "getInitialSharing") {
    if (initial_payload_.has_value()) {
      result->Success(flutter::EncodableValue(*initial_payload_));
    } else {
      result->Success(flutter::EncodableValue());
    }
  } else if (method == "clearInitialSharing") {
    initial_payload_.reset();
    result->Success(flutter::EncodableValue());
  } else if (method == "cleanupTempFiles") {
    result->Success(flutter::EncodableValue());
  } else {
    result->NotImplemented();
  }
}

}  // namespace xue_hua_navite_accept_sharing
