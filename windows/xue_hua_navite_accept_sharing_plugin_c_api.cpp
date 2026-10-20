#include "include/xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "xue_hua_navite_accept_sharing_plugin.h"

void XueHuaNaviteAcceptSharingPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  xue_hua_navite_accept_sharing::XueHuaNaviteAcceptSharingPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
