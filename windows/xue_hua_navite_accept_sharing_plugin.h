#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace xue_hua_navite_accept_sharing {

class XueHuaNaviteAcceptSharingPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  XueHuaNaviteAcceptSharingPlugin();

  virtual ~XueHuaNaviteAcceptSharingPlugin();

  // Disallow copy and assign.
  XueHuaNaviteAcceptSharingPlugin(const XueHuaNaviteAcceptSharingPlugin&) = delete;
  XueHuaNaviteAcceptSharingPlugin& operator=(const XueHuaNaviteAcceptSharingPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace xue_hua_navite_accept_sharing

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_
