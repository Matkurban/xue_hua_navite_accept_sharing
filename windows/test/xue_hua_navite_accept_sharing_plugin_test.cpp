#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>
#include <vector>

#include "xue_hua_navite_accept_sharing_plugin.h"

namespace xue_hua_navite_accept_sharing {
namespace test {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(XueHuaNaviteAcceptSharingPlugin, BuildPayloadFromArgumentsAndClear) {
  std::vector<std::string> args = {"--text", "https://flutter.dev"};
  auto payload = XueHuaNaviteAcceptSharingPlugin::BuildPayloadFromArguments(args);
  ASSERT_TRUE(payload.has_value());

  XueHuaNaviteAcceptSharingPlugin plugin;
  plugin.SetInitialPayload(payload);

  EncodableValue returned_value;
  plugin.HandleMethodCall(
      MethodCall("getInitialSharing", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&returned_value](const EncodableValue* result) {
            if (result != nullptr) {
              returned_value = *result;
            }
          },
          nullptr, nullptr));

  ASSERT_TRUE(std::holds_alternative<EncodableMap>(returned_value));
  const auto& result_map = std::get<EncodableMap>(returned_value);
  auto text_it = result_map.find(EncodableValue("text"));
  ASSERT_NE(text_it, result_map.end());
  EXPECT_EQ(std::get<std::string>(text_it->second), "https://flutter.dev");

  // Clear initial sharing and verify subsequent call returns null.
  plugin.HandleMethodCall(
      MethodCall("clearInitialSharing", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [](const EncodableValue* result) {}, nullptr, nullptr));

  bool is_null_after_clear = false;
  plugin.HandleMethodCall(
      MethodCall("getInitialSharing", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&is_null_after_clear](const EncodableValue* result) {
            is_null_after_clear = (result == nullptr || result->IsNull());
          },
          nullptr, nullptr));
  EXPECT_TRUE(is_null_after_clear);
}

}  // namespace test
}  // namespace xue_hua_navite_accept_sharing
