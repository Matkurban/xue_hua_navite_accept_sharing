#include "explorer_registration.h"

#include <windows.h>
#include <objbase.h>
#include <shlobj.h>
#include <shobjidl.h>

#include <string>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "uuid.lib")

namespace {

constexpr wchar_t kDisplayName[] = L"Xue Hua Accept Sharing Example";
constexpr wchar_t kShortcutFileName[] = L"Xue Hua Accept Sharing Example.lnk";
constexpr wchar_t kContextMenuLabel[] = L"Open with Xue Hua Accept Sharing Example";
constexpr wchar_t kProgId[] = L"XueHuaAcceptSharingExample.File";
constexpr wchar_t kVerbKey[] =
    L"Software\\Classes\\*\\shell\\XueHuaAcceptSharingExample";
constexpr wchar_t kVerbCommandKey[] =
    L"Software\\Classes\\*\\shell\\XueHuaAcceptSharingExample\\command";
constexpr wchar_t kProgIdKey[] = L"Software\\Classes\\XueHuaAcceptSharingExample.File";
constexpr wchar_t kProgIdOpenKey[] =
    L"Software\\Classes\\XueHuaAcceptSharingExample.File\\shell\\open";
constexpr wchar_t kProgIdCommandKey[] =
    L"Software\\Classes\\XueHuaAcceptSharingExample.File\\shell\\open\\command";

// Perceived types plus common extensions. The `*` verb covers every other file
// without taking over the default double-click association.
constexpr const wchar_t* kPerceivedTypes[] = {
    L"text", L"image", L"audio", L"video", L"compressed", L"document",
};
constexpr const wchar_t* kExtensions[] = {
    L".txt",  L".md",   L".json", L".csv",  L".log", L".pdf",  L".xml", L".html",
    L".htm",  L".png",  L".jpg",  L".jpeg", L".gif", L".webp", L".bmp", L".svg",
    L".mp4",  L".mov",  L".mkv",  L".avi",  L".webm", L".mp3", L".wav", L".ogg",
    L".m4a",  L".flac", L".zip",
};

constexpr DWORD kMaxPathChars = 32768;

DWORD WideStringBytes(const std::wstring& value) {
  const size_t bytes = (value.size() + 1) * sizeof(wchar_t);
  if (bytes > 0xffffffffu) {
    return 0;
  }
#pragma warning(push)
#pragma warning(disable : 4267)
  return static_cast<DWORD>(bytes);
#pragma warning(pop)
}

std::wstring ExecutablePath() {
  std::wstring path(kMaxPathChars, L'\0');
  const DWORD length = ::GetModuleFileNameW(nullptr, path.data(), kMaxPathChars);
  if (length == 0 || length >= kMaxPathChars) {
    return std::wstring();
  }
  path.resize(length);
  return path;
}

std::wstring FileNameOf(const std::wstring& path) {
  const auto slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return path;
  }
  return path.substr(slash + 1);
}

std::wstring ParentDirectory(const std::wstring& path) {
  const auto slash = path.find_last_of(L"\\/");
  if (slash == std::wstring::npos) {
    return L".";
  }
  return path.substr(0, slash);
}

std::wstring NormalizePath(std::wstring path) {
  if (path.empty()) {
    return path;
  }
  const DWORD needed = ::GetLongPathNameW(path.c_str(), nullptr, 0);
  if (needed > 0) {
    std::wstring long_path(needed, L'\0');
    const DWORD written = ::GetLongPathNameW(path.c_str(), long_path.data(), needed);
    if (written > 0 && written < needed) {
      long_path.resize(written);
      path = std::move(long_path);
    }
  }
  while (path.size() > 3 && (path.back() == L'\\' || path.back() == L'/')) {
    path.pop_back();
  }
  return path;
}

bool PathsEqual(const std::wstring& left, const std::wstring& right) {
  const std::wstring a = NormalizePath(left);
  const std::wstring b = NormalizePath(right);
  return ::CompareStringOrdinal(a.c_str(), -1, b.c_str(), -1, TRUE) == CSTR_EQUAL;
}

std::wstring QuoteCommand(const std::wstring& exe_path) {
  std::wstring command;
  command.reserve(exe_path.size() + 8);
  command.push_back(L'"');
  command.append(exe_path);
  command.append(L"\" \"%1\"");
  return command;
}

bool ReadStringValue(HKEY key, const wchar_t* name, std::wstring* value) {
  DWORD type = 0;
  DWORD bytes = 0;
  LONG result = ::RegQueryValueExW(key, name, nullptr, &type, nullptr, &bytes);
  if (result != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ)) {
    return false;
  }
  if (bytes < sizeof(wchar_t) || bytes % sizeof(wchar_t) != 0) {
    return false;
  }
  std::wstring data(bytes / sizeof(wchar_t), L'\0');
  result = ::RegQueryValueExW(key, name, nullptr, &type,
                              reinterpret_cast<BYTE*>(data.data()), &bytes);
  if (result != ERROR_SUCCESS) {
    return false;
  }
  while (!data.empty() && data.back() == L'\0') {
    data.pop_back();
  }
  *value = std::move(data);
  return true;
}

bool EnsureStringValue(HKEY root, const wchar_t* subkey, const wchar_t* name,
                       const std::wstring& value, bool* changed) {
  HKEY key = nullptr;
  const LONG opened = ::RegCreateKeyExW(
      root, subkey, 0, nullptr, REG_OPTION_NON_VOLATILE,
      KEY_QUERY_VALUE | KEY_SET_VALUE, nullptr, &key, nullptr);
  if (opened != ERROR_SUCCESS) {
    return false;
  }

  std::wstring existing;
  const bool same = ReadStringValue(key, name, &existing) && existing == value;
  LONG written = ERROR_SUCCESS;
  if (!same) {
    const DWORD bytes = WideStringBytes(value);
    if (bytes == 0) {
      ::RegCloseKey(key);
      return false;
    }
    written = ::RegSetValueExW(key, name, 0, REG_SZ,
                               reinterpret_cast<const BYTE*>(value.c_str()), bytes);
    if (written == ERROR_SUCCESS && changed != nullptr) {
      *changed = true;
    }
  }
  ::RegCloseKey(key);
  return same || written == ERROR_SUCCESS;
}

bool SendToDirectory(std::wstring* sendto_dir) {
  PWSTR raw_sendto = nullptr;
  if (FAILED(::SHGetKnownFolderPath(FOLDERID_SendTo, KF_FLAG_DEFAULT, nullptr,
                                    &raw_sendto)) ||
      raw_sendto == nullptr) {
    return false;
  }
  *sendto_dir = raw_sendto;
  ::CoTaskMemFree(raw_sendto);
  return true;
}

bool ReadShortcutTarget(const std::wstring& shortcut_path, std::wstring* target) {
  IShellLinkW* link = nullptr;
  HRESULT hr = ::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IShellLinkW, reinterpret_cast<void**>(&link));
  if (FAILED(hr) || link == nullptr) {
    return false;
  }
  IPersistFile* file = nullptr;
  hr = link->QueryInterface(IID_IPersistFile, reinterpret_cast<void**>(&file));
  if (FAILED(hr) || file == nullptr) {
    link->Release();
    return false;
  }
  hr = file->Load(shortcut_path.c_str(), STGM_READ);
  if (SUCCEEDED(hr)) {
    std::wstring existing(kMaxPathChars, L'\0');
    hr = link->GetPath(existing.data(), 32767, nullptr, SLGP_RAWPATH);
    if (SUCCEEDED(hr)) {
      existing.resize(wcsnlen(existing.c_str(), existing.size()));
      *target = std::move(existing);
    }
  }
  file->Release();
  link->Release();
  return SUCCEEDED(hr);
}

bool WriteSendToShortcut(const std::wstring& shortcut_path, const std::wstring& exe_path) {
  IShellLinkW* link = nullptr;
  HRESULT hr = ::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_IShellLinkW, reinterpret_cast<void**>(&link));
  if (FAILED(hr) || link == nullptr) {
    return false;
  }
  IPersistFile* file = nullptr;
  hr = link->QueryInterface(IID_IPersistFile, reinterpret_cast<void**>(&file));
  if (FAILED(hr) || file == nullptr) {
    link->Release();
    return false;
  }

  // Arguments stay empty. Explorer appends the selected files; a literal
  // "%1" in the shortcut would be delivered as text.
  link->SetPath(exe_path.c_str());
  link->SetWorkingDirectory(ParentDirectory(exe_path).c_str());
  link->SetArguments(L"");
  link->SetDescription(L"Send files to the Xue Hua Accept Sharing example");
  link->SetIconLocation(exe_path.c_str(), 0);
  hr = file->Save(shortcut_path.c_str(), TRUE);
  file->Release();
  link->Release();
  return SUCCEEDED(hr);
}

bool EnsureSendToShortcut(const std::wstring& exe_path, std::wstring* sendto_dir,
                          bool* changed) {
  if (!SendToDirectory(sendto_dir)) {
    return false;
  }
  const std::wstring shortcut_path = *sendto_dir + L"\\" + kShortcutFileName;

  std::wstring current_target;
  if (ReadShortcutTarget(shortcut_path, &current_target) &&
      PathsEqual(current_target, exe_path)) {
    return true;
  }
  if (!WriteSendToShortcut(shortcut_path, exe_path)) {
    return false;
  }
  if (changed != nullptr) {
    *changed = true;
  }
  return true;
}

void EnsureOpenWith(const std::wstring& exe_path, const std::wstring& command,
                    bool* changed) {
  const std::wstring exe_name = FileNameOf(exe_path);
  const std::wstring app_key = L"Software\\Classes\\Applications\\" + exe_name;
  const std::wstring app_command = app_key + L"\\shell\\open\\command";
  const std::wstring supported = app_key + L"\\SupportedTypes";

  EnsureStringValue(HKEY_CURRENT_USER, kProgIdKey, nullptr, kDisplayName, changed);
  EnsureStringValue(HKEY_CURRENT_USER, kProgIdOpenKey, L"MultiSelectModel", L"Player",
                    changed);
  EnsureStringValue(HKEY_CURRENT_USER, kProgIdCommandKey, nullptr, command, changed);
  EnsureStringValue(HKEY_CURRENT_USER, app_key.c_str(), L"FriendlyAppName", kDisplayName,
                    changed);
  EnsureStringValue(HKEY_CURRENT_USER, app_command.c_str(), nullptr, command, changed);

  for (const wchar_t* extension : kExtensions) {
    const std::wstring progids =
        std::wstring(L"Software\\Classes\\") + extension + L"\\OpenWithProgids";
    EnsureStringValue(HKEY_CURRENT_USER, progids.c_str(), kProgId, L"", changed);
    EnsureStringValue(HKEY_CURRENT_USER, supported.c_str(), extension, L"", changed);
  }
  for (const wchar_t* perceived : kPerceivedTypes) {
    const std::wstring progids =
        std::wstring(L"Software\\Classes\\SystemFileAssociations\\") + perceived +
        L"\\OpenWithProgids";
    EnsureStringValue(HKEY_CURRENT_USER, progids.c_str(), kProgId, L"", changed);
  }
}

void NotifyShell(bool registry_changed, bool shortcut_changed,
                 const std::wstring& sendto_dir) {
  if (registry_changed) {
    ::SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST | SHCNF_FLUSHNOWAIT, nullptr,
                     nullptr);
  }
  if (shortcut_changed && !sendto_dir.empty()) {
    ::SHChangeNotify(SHCNE_UPDATEDIR, SHCNF_PATH | SHCNF_FLUSHNOWAIT, sendto_dir.c_str(),
                     nullptr);
  }
}

}  // namespace

void RegisterExplorerIntegration() {
  const std::wstring exe_path = ExecutablePath();
  if (exe_path.empty()) {
    ::OutputDebugStringW(L"Xue Hua Accept Sharing: executable path unavailable\n");
    return;
  }

  bool registry_changed = false;
  bool shortcut_changed = false;
  std::wstring sendto_dir;
  const std::wstring command = QuoteCommand(exe_path);
  const std::wstring icon = exe_path + L",0";

  if (!EnsureSendToShortcut(exe_path, &sendto_dir, &shortcut_changed)) {
    ::OutputDebugStringW(L"Xue Hua Accept Sharing: Send to shortcut was not updated\n");
  }

  const bool verb_ok =
      EnsureStringValue(HKEY_CURRENT_USER, kVerbKey, nullptr, kContextMenuLabel,
                        &registry_changed) &&
      EnsureStringValue(HKEY_CURRENT_USER, kVerbKey, L"Icon", icon, &registry_changed) &&
      EnsureStringValue(HKEY_CURRENT_USER, kVerbKey, L"MultiSelectModel", L"Player",
                        &registry_changed) &&
      EnsureStringValue(HKEY_CURRENT_USER, kVerbCommandKey, nullptr, command,
                        &registry_changed);
  if (!verb_ok) {
    ::OutputDebugStringW(L"Xue Hua Accept Sharing: context menu was not registered\n");
  }

  EnsureOpenWith(exe_path, command, &registry_changed);
  NotifyShell(registry_changed, shortcut_changed, sendto_dir);
}
