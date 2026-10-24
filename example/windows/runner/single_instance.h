#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <string>
#include <vector>

// Title and class passed to FindWindow. The title must match FlutterWindow::Create.
inline constexpr wchar_t kExampleWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
inline constexpr wchar_t kExampleWindowTitle[] = L"xue_hua_navite_accept_sharing_example";

// When an example window is already open, forwards [utf8_args] with WM_COPYDATA
// (dwData = 0x58485348) and returns true. The caller must exit without creating
// another window. Returns false when this process should become the primary instance.
bool ForwardToExistingInstance(const std::vector<std::string>& utf8_args);

#endif  // RUNNER_SINGLE_INSTANCE_H_
