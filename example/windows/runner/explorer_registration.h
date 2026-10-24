#ifndef RUNNER_EXPLORER_REGISTRATION_H_
#define RUNNER_EXPLORER_REGISTRATION_H_

// Points File Explorer at the running executable:
//   - a shortcut in shell:sendto (发送到 / Send to)
//   - a per-user context-menu verb on every file
//   - Open with handlers for common types
// HKCU only, so `flutter run` can register without an installer or admin.
// Call after CoInitializeEx(COINIT_APARTMENTTHREADED). Failures are ignored.
void RegisterExplorerIntegration();

#endif  // RUNNER_EXPLORER_REGISTRATION_H_
