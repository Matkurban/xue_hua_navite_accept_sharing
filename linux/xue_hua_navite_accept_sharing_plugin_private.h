#include <flutter_linux/flutter_linux.h>

#include "include/xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_plugin.h"

// Parses an array of command-line arguments into a SharedPayload FlValue map
// (or nullptr if no shared arguments are present).
FlValue* parse_shared_arguments(const gchar* const* args, gint argc);
