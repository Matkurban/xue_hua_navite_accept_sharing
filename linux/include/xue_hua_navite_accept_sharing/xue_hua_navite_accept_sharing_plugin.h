#ifndef FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_
#define FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _XueHuaNaviteAcceptSharingPlugin XueHuaNaviteAcceptSharingPlugin;
typedef struct {
  GObjectClass parent_class;
} XueHuaNaviteAcceptSharingPluginClass;

FLUTTER_PLUGIN_EXPORT GType xue_hua_navite_accept_sharing_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void xue_hua_navite_accept_sharing_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

/**
 * Forwards command-line share arguments into the plugin.
 *
 * Call from the host GtkApplication when a unique-instance `command-line`
 * activation delivers new argv (Open with / .desktop %U / --text). If Dart is
 * already listening on `onSharingReceived`, the payload is emitted as a warm
 * event; otherwise it is stored for `getInitialSharing`.
 */
FLUTTER_PLUGIN_EXPORT void xue_hua_navite_accept_sharing_plugin_dispatch_arguments(
    const gchar* const* args,
    gint argc);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN_H_
