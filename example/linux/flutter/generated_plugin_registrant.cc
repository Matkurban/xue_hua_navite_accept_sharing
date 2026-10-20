//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) xue_hua_navite_accept_sharing_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "XueHuaNaviteAcceptSharingPlugin");
  xue_hua_navite_accept_sharing_plugin_register_with_registrar(xue_hua_navite_accept_sharing_registrar);
}
