#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include "include/xue_hua_navite_accept_sharing/xue_hua_navite_accept_sharing_plugin.h"
#include "xue_hua_navite_accept_sharing_plugin_private.h"

namespace xue_hua_navite_accept_sharing {
namespace test {

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsUrlAndText) {
  const gchar* args[] = {"--text", "https://flutter.dev"};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 2);
  ASSERT_NE(payload, nullptr);
  ASSERT_EQ(fl_value_get_type(payload), FL_VALUE_TYPE_MAP);

  FlValue* text_val = fl_value_lookup_string(payload, "text");
  ASSERT_NE(text_val, nullptr);
  EXPECT_STREQ(fl_value_get_string(text_val), "https://flutter.dev");

  FlValue* items_val = fl_value_lookup_string(payload, "items");
  ASSERT_NE(items_val, nullptr);
  ASSERT_EQ(fl_value_get_type(items_val), FL_VALUE_TYPE_LIST);
  ASSERT_EQ(fl_value_get_length(items_val), 1u);

  FlValue* first_item = fl_value_get_list_value(items_val, 0);
  FlValue* item_type = fl_value_lookup_string(first_item, "type");
  EXPECT_STREQ(fl_value_get_string(item_type), "url");
}

}  // namespace test
}  // namespace xue_hua_navite_accept_sharing
