#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace xue_hua_navite_accept_sharing {

class XueHuaNaviteAcceptSharingPlugin : public flutter::Plugin {
 public:
  static constexpr ULONG_PTR kShareCopyDataMagic = 0x58485348;  // 'XHSH'

  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit XueHuaNaviteAcceptSharingPlugin(
      flutter::PluginRegistrarWindows *registrar = nullptr);

  virtual ~XueHuaNaviteAcceptSharingPlugin();

  // Disallow copy and assign.
  XueHuaNaviteAcceptSharingPlugin(const XueHuaNaviteAcceptSharingPlugin&) = delete;
  XueHuaNaviteAcceptSharingPlugin& operator=(
      const XueHuaNaviteAcceptSharingPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Parses command-line or WM_COPYDATA arguments into a SharedPayload map.
  static std::optional<flutter::EncodableMap> BuildPayloadFromArguments(
      const std::vector<std::string> &args);

  // For testing and manual injection.
  void SetInitialPayload(std::optional<flutter::EncodableMap> payload) {
    initial_payload_ = std::move(payload);
  }

 private:
  void ParseInitialCommandLine();
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam);

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  int window_proc_id_ = -1;
  std::optional<flutter::EncodableMap> initial_payload_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
};

}  // namespace xue_hua_navite_accept_sharing

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_
