#include "include/xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

#include <cstring>

#include "xue_hua_navite_accept_sharing_plugin_private.h"

#define XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), xue_hua_navite_accept_sharing_plugin_get_type(), \
                              XueHuaNaviteAcceptSharingPlugin))

struct _XueHuaNaviteAcceptSharingPlugin {
  GObject parent_instance;
  FlValue* initial_payload;
  FlEventChannel* event_channel;
};

G_DEFINE_TYPE(XueHuaNaviteAcceptSharingPlugin,
              xue_hua_navite_accept_sharing_plugin,
              g_object_get_type())

static const gchar* classify_mime_type(const gchar* mime_type) {
  if (mime_type == nullptr) {
    return "file";
  }
  if (g_str_has_prefix(mime_type, "image/")) {
    return "image";
  }
  if (g_str_has_prefix(mime_type, "video/")) {
    return "video";
  }
  if (g_str_has_prefix(mime_type, "audio/")) {
    return "audio";
  }
  return "file";
}

static FlValue* build_file_item(const gchar* file_path) {
  g_autoptr(GFile) gfile = g_file_new_for_path(file_path);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GFileInfo) info = g_file_query_info(
      gfile,
      G_FILE_ATTRIBUTE_STANDARD_TYPE ","
      G_FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME ","
      G_FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE ","
      G_FILE_ATTRIBUTE_STANDARD_SIZE,
      G_FILE_QUERY_INFO_NONE, nullptr, &error);

  if (info == nullptr ||
      g_file_info_get_file_type(info) == G_FILE_TYPE_DIRECTORY) {
    return nullptr;
  }

  const gchar* display_name = g_file_info_get_display_name(info);
  const gchar* content_type = g_file_info_get_content_type(info);
  g_autofree gchar* mime_type =
      content_type != nullptr ? g_content_type_get_mime_type(content_type)
                              : g_strdup("application/octet-stream");
  goffset file_size = g_file_info_get_size(info);
  const gchar* item_type = classify_mime_type(mime_type);

  FlValue* item = fl_value_new_map();
  fl_value_set_string_take(item, "type", fl_value_new_string(item_type));
  fl_value_set_string_take(item, "content", fl_value_new_string(file_path));
  if (display_name != nullptr) {
    fl_value_set_string_take(item, "fileName",
                             fl_value_new_string(display_name));
  }
  if (mime_type != nullptr) {
    fl_value_set_string_take(item, "mimeType", fl_value_new_string(mime_type));
  }
  fl_value_set_string_take(item, "fileSize", fl_value_new_int(file_size));
  return item;
}

static FlValue* build_text_item(const gchar* text) {
  gboolean is_url = g_str_has_prefix(text, "http://") ||
                    g_str_has_prefix(text, "https://");
  FlValue* item = fl_value_new_map();
  fl_value_set_string_take(item, "type",
                           fl_value_new_string(is_url ? "url" : "text"));
  fl_value_set_string_take(item, "content", fl_value_new_string(text));
  fl_value_set_string_take(
      item, "mimeType",
      fl_value_new_string(is_url ? "text/uri-list" : "text/plain"));
  return item;
}

FlValue* parse_shared_arguments(const gchar* const* args, gint argc) {
  if (args == nullptr || argc <= 0) {
    return nullptr;
  }

  g_autoptr(FlValue) items = fl_value_new_list();
  g_autofree gchar* shared_text = nullptr;

  for (gint i = 0; i < argc; ++i) {
    const gchar* arg = args[i];
    if (arg == nullptr || arg[0] == '\0') {
      continue;
    }

    if (g_strcmp0(arg, "--text") == 0 && i + 1 < argc) {
      const gchar* next_arg = args[++i];
      if (shared_text == nullptr) {
        shared_text = g_strdup(next_arg);
      }
      fl_value_append_take(items, build_text_item(next_arg));
      continue;
    }

    if (g_str_has_prefix(arg, "--")) {
      continue;
    }

    if (g_str_has_prefix(arg, "file://")) {
      g_autofree gchar* local_path = g_filename_from_uri(arg, nullptr, nullptr);
      if (local_path != nullptr &&
          g_file_test(local_path, G_FILE_TEST_IS_REGULAR)) {
        FlValue* file_item = build_file_item(local_path);
        if (file_item != nullptr) {
          fl_value_append_take(items, file_item);
          continue;
        }
      }
    }

    if (g_str_has_prefix(arg, "http://") || g_str_has_prefix(arg, "https://")) {
      fl_value_append_take(items, build_text_item(arg));
      continue;
    }

    if (g_file_test(arg, G_FILE_TEST_IS_REGULAR)) {
      FlValue* file_item = build_file_item(arg);
      if (file_item != nullptr) {
        fl_value_append_take(items, file_item);
        continue;
      }
    }

    if (shared_text == nullptr) {
      shared_text = g_strdup(arg);
    }
    fl_value_append_take(items, build_text_item(arg));
  }

  if (fl_value_get_length(items) == 0 && shared_text == nullptr) {
    return nullptr;
  }

  FlValue* payload = fl_value_new_map();
  fl_value_set_string_take(payload, "items", fl_value_ref(items));
  if (shared_text != nullptr) {
    fl_value_set_string_take(payload, "text", fl_value_new_string(shared_text));
  }
  return payload;
}

static FlValue* parse_proc_cmdline() {
  g_autofree gchar* cmdline = nullptr;
  gsize length = 0;
  if (!g_file_get_contents("/proc/self/cmdline", &cmdline, &length, nullptr) ||
      length == 0) {
    return nullptr;
  }

  GPtrArray* ptr_array = g_ptr_array_new();
  gsize offset = 0;
  gboolean first = TRUE;
  while (offset < length) {
    const gchar* token = cmdline + offset;
    gsize token_len = strlen(token);
    if (!first && token_len > 0) {
      g_ptr_array_add(ptr_array, const_cast<gchar*>(token));
    }
    first = FALSE;
    offset += token_len + 1;
  }

  FlValue* payload = parse_shared_arguments(
      reinterpret_cast<const gchar* const*>(ptr_array->pdata),
      static_cast<gint>(ptr_array->len));
  g_ptr_array_free(ptr_array, TRUE);
  return payload;
}

static void xue_hua_navite_accept_sharing_plugin_handle_method_call(
    XueHuaNaviteAcceptSharingPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "getInitialSharing") == 0) {
    if (self->initial_payload != nullptr) {
      response = FL_METHOD_RESPONSE(
          fl_method_success_response_new(self->initial_payload));
    } else {
      g_autoptr(FlValue) null_val = fl_value_new_null();
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(null_val));
    }
  } else if (strcmp(method, "clearInitialSharing") == 0) {
    g_clear_pointer(&self->initial_payload, fl_value_unref);
    g_autoptr(FlValue) null_val = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(null_val));
  } else if (strcmp(method, "cleanupTempFiles") == 0) {
    g_autoptr(FlValue) null_val = fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(null_val));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void xue_hua_navite_accept_sharing_plugin_dispose(GObject* object) {
  XueHuaNaviteAcceptSharingPlugin* self =
      XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN(object);
  g_clear_pointer(&self->initial_payload, fl_value_unref);
  g_clear_object(&self->event_channel);
  G_OBJECT_CLASS(xue_hua_navite_accept_sharing_plugin_parent_class)
      ->dispose(object);
}

static void xue_hua_navite_accept_sharing_plugin_class_init(
    XueHuaNaviteAcceptSharingPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = xue_hua_navite_accept_sharing_plugin_dispose;
}

static void xue_hua_navite_accept_sharing_plugin_init(
    XueHuaNaviteAcceptSharingPlugin* self) {
  self->initial_payload = parse_proc_cmdline();
  self->event_channel = nullptr;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  XueHuaNaviteAcceptSharingPlugin* plugin =
      XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN(user_data);
  xue_hua_navite_accept_sharing_plugin_handle_method_call(plugin, method_call);
}

void xue_hua_navite_accept_sharing_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  XueHuaNaviteAcceptSharingPlugin* plugin = XUE_HUA_NAVITE_ACCEPT_SHARING_PLUGIN(
      g_object_new(xue_hua_navite_accept_sharing_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "xue_hua_navite_accept_sharing",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  plugin->event_channel =
      fl_event_channel_new(fl_plugin_registrar_get_messenger(registrar),
                           "xue_hua_navite_accept_sharing/events",
                           FL_METHOD_CODEC(codec));

  g_object_unref(plugin);
}
