#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "update_bridge.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (!UpdateBridge::RunStartup()) return EXIT_SUCCESS;
  // Workers and fast hooks have already exited. Keep one background host per
  // Windows session, including repeated launches during updater recovery.
  HANDLE instance_mutex = CreateMutexW(
      nullptr, FALSE, L"Local\\OpenRemoteControl.org.openremotecontrol.windows.Server");
  if (!instance_mutex || GetLastError() == ERROR_ALREADY_EXISTS) {
    if (instance_mutex) CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }
  // Portable launchers may inherit the root (or another) working directory.
  // Flutter's data directory is relative to the actual executable in current/.
  wchar_t executable_path[32768];
  if (!GetModuleFileNameW(nullptr, executable_path, 32768)) return EXIT_FAILURE;
  wchar_t* separator = wcsrchr(executable_path, L'\\');
  if (!separator) return EXIT_FAILURE;
  *separator = L'\0';
  if (!SetCurrentDirectoryW(executable_path)) return EXIT_FAILURE;
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Open Remote Control", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
