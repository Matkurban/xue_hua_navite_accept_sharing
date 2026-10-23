#include "single_instance.h"

#include <windows.h>

#include <string>

namespace {

constexpr ULONG_PTR kShareCopyDataMagic = 0x58485348;  // 'XHSH'
constexpr wchar_t kSingleInstanceMutex[] = L"Local\\XueHuaNaviteAcceptSharingExample";
constexpr int kDeliverAttempts = 40;
constexpr DWORD kDeliverPauseMs = 100;
constexpr DWORD kSendTimeoutMs = 500;
constexpr DWORD kWindowWaitMs = 15000;

// Command lines are far below 4 GB. Narrow explicitly so /W4 /WX stays clean.
DWORD PayloadBytes(size_t size) {
#pragma warning(push)
#pragma warning(disable : 4267)
  return static_cast<DWORD>(size);
#pragma warning(pop)
}

std::string JoinArgs(const std::vector<std::string>& args) {
  std::string joined;
  size_t bytes = 0;
  for (const auto& arg : args) {
    bytes += arg.size() + 1;
  }
  joined.reserve(bytes);
  for (const auto& arg : args) {
    joined.append(arg);
    joined.push_back('\n');
  }
  return joined;
}

HWND FindExampleWindow() {
  return ::FindWindowW(kExampleWindowClassName, kExampleWindowTitle);
}

HWND WaitForExampleWindow(DWORD timeout_ms) {
  const ULONGLONG deadline = ::GetTickCount64() + timeout_ms;
  for (;;) {
    if (HWND hwnd = FindExampleWindow()) {
      return hwnd;
    }
    if (::GetTickCount64() >= deadline) {
      return nullptr;
    }
    ::Sleep(50);
  }
}

// Keeps the mutex alive until this process exits. A local HANDLE does not
// close the kernel object when it goes out of scope.
bool AnotherInstanceOwnsMutex() {
  // CreateMutex only sets ERROR_ALREADY_EXISTS when the name is taken. Clear
  // any stale code first so a failed FindWindow cannot look like a second instance.
  ::SetLastError(ERROR_SUCCESS);
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (mutex == nullptr) {
    return false;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    ::CloseHandle(mutex);
    return true;
  }
  return false;
}

bool SendPayload(HWND hwnd, const std::string& payload) {
  COPYDATASTRUCT cds{};
  cds.dwData = kShareCopyDataMagic;
  cds.cbData = PayloadBytes(payload.size());
  cds.lpData = const_cast<char*>(payload.data());
  DWORD_PTR result = 0;
  const LRESULT sent = ::SendMessageTimeoutW(
      hwnd, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds),
      SMTO_ABORTIFHUNG | SMTO_BLOCK, kSendTimeoutMs, &result);
  return sent != 0 && result == 1;
}

void Deliver(HWND hwnd, const std::string& payload) {
  if (payload.empty()) {
    return;
  }
  for (int attempt = 0; attempt < kDeliverAttempts; ++attempt) {
    if (!::IsWindow(hwnd)) {
      hwnd = FindExampleWindow();
      if (hwnd == nullptr) {
        return;
      }
    }
    if (SendPayload(hwnd, payload)) {
      return;
    }
    ::Sleep(kDeliverPauseMs);
  }
}

void ActivateWindow(HWND hwnd) {
  const HWND foreground = ::GetForegroundWindow();
  const DWORD foreground_thread =
      foreground != nullptr ? ::GetWindowThreadProcessId(foreground, nullptr) : 0;
  const DWORD target_thread = ::GetWindowThreadProcessId(hwnd, nullptr);
  const DWORD current_thread = ::GetCurrentThreadId();

  const bool attached_foreground =
      foreground_thread != 0 && foreground_thread != current_thread &&
      ::AttachThreadInput(current_thread, foreground_thread, TRUE) != FALSE;
  const bool attached_target =
      target_thread != 0 && target_thread != current_thread &&
      target_thread != foreground_thread &&
      ::AttachThreadInput(current_thread, target_thread, TRUE) != FALSE;

  if (::IsIconic(hwnd)) {
    ::ShowWindow(hwnd, SW_RESTORE);
  } else {
    ::ShowWindow(hwnd, SW_SHOW);
  }
  ::BringWindowToTop(hwnd);
  ::SetForegroundWindow(hwnd);

  if (attached_target) {
    ::AttachThreadInput(current_thread, target_thread, FALSE);
  }
  if (attached_foreground) {
    ::AttachThreadInput(current_thread, foreground_thread, FALSE);
  }
}

}  // namespace

bool ForwardToExistingInstance(const std::vector<std::string>& utf8_args) {
  const std::string payload = JoinArgs(utf8_args);

  if (HWND existing = FindExampleWindow()) {
    Deliver(existing, payload);
    ActivateWindow(existing);
    return true;
  }

  // Another launch is still creating its window. Wait, then hand off.
  if (AnotherInstanceOwnsMutex()) {
    if (HWND existing = WaitForExampleWindow(kWindowWaitMs)) {
      Deliver(existing, payload);
      ActivateWindow(existing);
      return true;
    }
  }

  // This process owns the instance mutex. Let a later Send to / Open with
  // process bring the window forward.
  ::AllowSetForegroundWindow(ASFW_ANY);
  return false;
}
