#include "flutter_window.h"

#include <algorithm>
#include <cmath>
#include <map>
#include <optional>
#include <string>
#include <variant>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  input_channel_ = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "open_remote/input",
      &flutter::StandardMethodCodec::GetInstance());
  input_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto* arguments =
            std::get_if<flutter::EncodableMap>(call.arguments());
        const auto read_string = [&](const char* name,
                                     std::string* value) -> bool {
          if (arguments == nullptr) return false;
          const auto item = arguments->find(
              flutter::EncodableValue(std::string(name)));
          if (item == arguments->end()) return false;
          const auto* string_value = std::get_if<std::string>(&item->second);
          if (string_value == nullptr) return false;
          *value = *string_value;
          return true;
        };
        const auto read_number = [&](const char* name,
                                     double* value) -> bool {
          if (arguments == nullptr) return false;
          const auto item = arguments->find(
              flutter::EncodableValue(std::string(name)));
          if (item == arguments->end()) return false;
          const auto* number = std::get_if<double>(&item->second);
          if (number == nullptr || !std::isfinite(*number)) return false;
          *value = *number;
          return true;
        };
        const auto read_boolean = [&](const char* name,
                                      bool* value) -> bool {
          if (arguments == nullptr) return false;
          const auto item = arguments->find(
              flutter::EncodableValue(std::string(name)));
          if (item == arguments->end()) return false;
          const auto* boolean_value = std::get_if<bool>(&item->second);
          if (boolean_value == nullptr) return false;
          *value = *boolean_value;
          return true;
        };
        const auto send_key = [&](WORD key) -> bool {
          INPUT input{};
          input.type = INPUT_KEYBOARD;
          input.ki.wVk = key;
          if (SendInput(1, &input, sizeof(INPUT)) != 1) return false;
          input.ki.dwFlags = KEYEVENTF_KEYUP;
          return SendInput(1, &input, sizeof(INPUT)) == 1;
        };

        if (call.method_name() == "mouseMove") {
          double dx = 0;
          double dy = 0;
          if (!read_number("dx", &dx) || !read_number("dy", &dy) ||
              std::abs(dx) > 500 || std::abs(dy) > 500) {
            result->Error("invalid_arguments", "Invalid mouse movement.");
            return;
          }
          INPUT input{};
          input.type = INPUT_MOUSE;
          input.mi.dx = static_cast<LONG>(std::lround(dx));
          input.mi.dy = static_cast<LONG>(std::lround(dy));
          input.mi.dwFlags = MOUSEEVENTF_MOVE;
          if (SendInput(1, &input, sizeof(INPUT)) != 1) {
            result->Error("input_failed", "Windows rejected mouse input.");
            return;
          }
          result->Success();
          return;
        }

        if (call.method_name() == "mouseButton") {
          std::string button;
          if (!read_string("button", &button) || arguments == nullptr) {
            result->Error("invalid_arguments", "Invalid mouse button.");
            return;
          }
          const auto pressed_item = arguments->find(
              flutter::EncodableValue(std::string("pressed")));
          if (pressed_item == arguments->end()) {
            result->Error("invalid_arguments", "Missing button state.");
            return;
          }
          const auto* pressed = std::get_if<bool>(&pressed_item->second);
          if (pressed == nullptr) {
            result->Error("invalid_arguments", "Invalid button state.");
            return;
          }
          DWORD flag = 0;
          if (button == "left") {
            flag = *pressed ? MOUSEEVENTF_LEFTDOWN : MOUSEEVENTF_LEFTUP;
          } else if (button == "right") {
            flag = *pressed ? MOUSEEVENTF_RIGHTDOWN : MOUSEEVENTF_RIGHTUP;
          } else if (button == "middle") {
            flag = *pressed ? MOUSEEVENTF_MIDDLEDOWN : MOUSEEVENTF_MIDDLEUP;
          } else {
            result->Error("invalid_arguments", "Unsupported mouse button.");
            return;
          }
          INPUT input{};
          input.type = INPUT_MOUSE;
          input.mi.dwFlags = flag;
          if (SendInput(1, &input, sizeof(INPUT)) != 1) {
            result->Error("input_failed", "Windows rejected mouse input.");
            return;
          }
          result->Success();
          return;
        }

        if (call.method_name() == "mouseScroll") {
          double delta = 0;
          if (!read_number("delta", &delta) || std::abs(delta) > 1200) {
            result->Error("invalid_arguments", "Invalid scroll delta.");
            return;
          }
          INPUT input{};
          input.type = INPUT_MOUSE;
          input.mi.dwFlags = MOUSEEVENTF_WHEEL;
          input.mi.mouseData = static_cast<DWORD>(
              static_cast<LONG>(std::lround(delta)));
          if (SendInput(1, &input, sizeof(INPUT)) != 1) {
            result->Error("input_failed", "Windows rejected mouse input.");
            return;
          }
          result->Success();
          return;
        }

        if (call.method_name() == "typeText") {
          std::string text;
          if (!read_string("text", &text) || text.size() > 2048) {
            result->Error("invalid_arguments", "Invalid keyboard text.");
            return;
          }
          if (text.empty()) {
            result->Success();
            return;
          }
          const int length = MultiByteToWideChar(
              CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
              static_cast<int>(text.size()), nullptr, 0);
          if (length <= 0 || length > 512) {
            result->Error("invalid_arguments", "Keyboard text is too long.");
            return;
          }
          std::vector<wchar_t> wide_text(length);
          if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                                  static_cast<int>(text.size()),
                                  wide_text.data(), length) != length) {
            result->Error("invalid_arguments", "Keyboard text is invalid.");
            return;
          }
          std::vector<INPUT> inputs;
          inputs.reserve(length * 2);
          for (const wchar_t character : wide_text) {
            INPUT down{};
            down.type = INPUT_KEYBOARD;
            down.ki.wScan = character;
            down.ki.dwFlags = KEYEVENTF_UNICODE;
            INPUT up = down;
            up.ki.dwFlags |= KEYEVENTF_KEYUP;
            inputs.push_back(down);
            inputs.push_back(up);
          }
          const auto sent = SendInput(static_cast<UINT>(inputs.size()),
                                      inputs.data(), sizeof(INPUT));
          if (sent != static_cast<UINT>(inputs.size())) {
            result->Error("input_failed", "Windows rejected keyboard input.");
            return;
          }
          result->Success();
          return;
        }

        if (call.method_name() == "pressKey") {
          std::string key;
          if (!read_string("key", &key)) {
            result->Error("invalid_arguments", "Invalid key.");
            return;
          }
          static const std::map<std::string, int> key_codes = {
              {"enter", VK_RETURN},     {"backspace", VK_BACK},
              {"tab", VK_TAB},          {"escape", VK_ESCAPE},
              {"space", VK_SPACE},      {"arrowUp", VK_UP},
              {"arrowDown", VK_DOWN},   {"arrowLeft", VK_LEFT},
              {"arrowRight", VK_RIGHT}, {"delete", VK_DELETE},
              {"home", VK_HOME},        {"end", VK_END},
              {"pageUp", VK_PRIOR},     {"pageDown", VK_NEXT},
              {"insert", VK_INSERT},    {"capsLock", VK_CAPITAL},
              {"f1", VK_F1},            {"f2", VK_F2},
              {"f3", VK_F3},            {"f4", VK_F4},
              {"f5", VK_F5},            {"f6", VK_F6},
              {"f7", VK_F7},            {"f8", VK_F8},
              {"f9", VK_F9},            {"f10", VK_F10},
              {"f11", VK_F11},          {"f12", VK_F12},
          };
          std::optional<WORD> key_code;
          const auto mapped_key = key_codes.find(key);
          if (mapped_key != key_codes.end()) {
            key_code = static_cast<WORD>(mapped_key->second);
          } else if (key.size() == 1 && key[0] >= 'a' && key[0] <= 'z') {
            key_code = static_cast<WORD>(key[0] - 'a' + 'A');
          } else if (key.size() == 1 && key[0] >= '0' && key[0] <= '9') {
            key_code = static_cast<WORD>(key[0]);
          }
          if (!key_code || !send_key(*key_code)) {
            result->Error("input_failed", "Windows rejected the key.");
            return;
          }
          result->Success();
          return;
        }

        if (call.method_name() == "keyState") {
          std::string key;
          bool pressed = false;
          if (!read_string("key", &key) ||
              !read_boolean("pressed", &pressed)) {
            result->Error("invalid_arguments", "Invalid key state.");
            return;
          }
          static const std::map<std::string, int> modifier_codes = {
              {"control", VK_CONTROL}, {"alt", VK_MENU},
              {"shift", VK_SHIFT},
          };
          const auto modifier = modifier_codes.find(key);
          if (modifier == modifier_codes.end()) {
            result->Error("invalid_arguments", "Unsupported modifier.");
            return;
          }
          INPUT input{};
          input.type = INPUT_KEYBOARD;
          input.ki.wVk = static_cast<WORD>(modifier->second);
          input.ki.dwFlags = pressed ? 0 : KEYEVENTF_KEYUP;
          if (SendInput(1, &input, sizeof(INPUT)) != 1) {
            result->Error("input_failed", "Windows rejected the modifier.");
            return;
          }
          result->Success();
          return;
        }

        if (call.method_name() == "media") {
          std::string command;
          if (!read_string("command", &command)) {
            result->Error("invalid_arguments", "Invalid media command.");
            return;
          }
          static const std::map<std::string, int> media_codes = {
              {"volumeUp", VK_VOLUME_UP},
              {"volumeDown", VK_VOLUME_DOWN},
              {"volumeMute", VK_VOLUME_MUTE},
              {"playPause", VK_MEDIA_PLAY_PAUSE},
              {"nextTrack", VK_MEDIA_NEXT_TRACK},
              {"previousTrack", VK_MEDIA_PREV_TRACK},
          };
          const auto key_code = media_codes.find(command);
          if (key_code == media_codes.end() ||
              !send_key(static_cast<WORD>(key_code->second))) {
            result->Error("input_failed", "Windows rejected the media key.");
            return;
          }
          result->Success();
          return;
        }

        result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Keep the host window hidden; Windows control is managed from the tray and
  // the local dashboard runs in the user's browser.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (input_channel_) {
    input_channel_->SetMethodCallHandler(nullptr);
    input_channel_.reset();
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
