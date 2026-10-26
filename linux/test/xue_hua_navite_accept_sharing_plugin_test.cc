#include <flutter_linux/flutter_linux.h>
#include <gmock/gmock.h>
#include <gtest/gtest.h>

#include <cstdio>
#include <string>

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

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsPlainText) {
  const gchar* args[] = {"--text", "hello-share"};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 2);
  ASSERT_NE(payload, nullptr);

  FlValue* text_val = fl_value_lookup_string(payload, "text");
  ASSERT_NE(text_val, nullptr);
  EXPECT_STREQ(fl_value_get_string(text_val), "hello-share");

  FlValue* items_val = fl_value_lookup_string(payload, "items");
  ASSERT_NE(items_val, nullptr);
  ASSERT_EQ(fl_value_get_length(items_val), 1u);
  FlValue* first_item = fl_value_get_list_value(items_val, 0);
  EXPECT_STREQ(fl_value_get_string(fl_value_lookup_string(first_item, "type")),
               "text");
}

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsSkipsUnknownFlags) {
  const gchar* args[] = {"--enable-dart-profiling", "--trace-startup"};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 2);
  EXPECT_EQ(payload, nullptr);
}

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsEmpty) {
  const gchar* args[] = {nullptr};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 0);
  EXPECT_EQ(payload, nullptr);
}

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsRegularFile) {
  const char* path = "/tmp/share_test_assets/hello.txt";
  FILE* f = fopen(path, "we");
  ASSERT_NE(f, nullptr);
  fputs("hello share content\n", f);
  fclose(f);

  const gchar* args[] = {path};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 1);
  ASSERT_NE(payload, nullptr);

  FlValue* items_val = fl_value_lookup_string(payload, "items");
  ASSERT_NE(items_val, nullptr);
  ASSERT_EQ(fl_value_get_length(items_val), 1u);

  FlValue* first_item = fl_value_get_list_value(items_val, 0);
  EXPECT_STREQ(fl_value_get_string(fl_value_lookup_string(first_item, "type")),
               "file");
  EXPECT_STREQ(
      fl_value_get_string(fl_value_lookup_string(first_item, "content")), path);
  FlValue* name = fl_value_lookup_string(first_item, "fileName");
  ASSERT_NE(name, nullptr);
  EXPECT_STREQ(fl_value_get_string(name), "hello.txt");
}

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsFileUri) {
  const char* path = "/tmp/share_test_assets/hello.txt";
  FILE* f = fopen(path, "we");
  ASSERT_NE(f, nullptr);
  fputs("hello\n", f);
  fclose(f);

  g_autofree gchar* uri = g_filename_to_uri(path, nullptr, nullptr);
  ASSERT_NE(uri, nullptr);

  const gchar* args[] = {uri};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 1);
  ASSERT_NE(payload, nullptr);

  FlValue* items_val = fl_value_lookup_string(payload, "items");
  ASSERT_NE(items_val, nullptr);
  ASSERT_EQ(fl_value_get_length(items_val), 1u);
  FlValue* first_item = fl_value_get_list_value(items_val, 0);
  EXPECT_STREQ(
      fl_value_get_string(fl_value_lookup_string(first_item, "content")), path);
}

TEST(XueHuaNaviteAcceptSharingPlugin, ParseSharedArgumentsBareHttpsUrl) {
  const gchar* args[] = {"https://example.com/path"};
  g_autoptr(FlValue) payload = parse_shared_arguments(args, 1);
  ASSERT_NE(payload, nullptr);
  FlValue* items_val = fl_value_lookup_string(payload, "items");
  ASSERT_NE(items_val, nullptr);
  FlValue* first_item = fl_value_get_list_value(items_val, 0);
  EXPECT_STREQ(fl_value_get_string(fl_value_lookup_string(first_item, "type")),
               "url");
}

}  // namespace test
}  // namespace xue_hua_navite_accept_sharing
