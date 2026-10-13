#ifndef RUNNER_UPDATE_BRIDGE_H_
#define RUNNER_UPDATE_BRIDGE_H_
#include <flutter/binary_messenger.h>
#include <windows.h>
#include <memory>

// SDK exceptions, process supervision and channels live entirely in this target.
class UpdateBridge {
 public:
  static bool RunStartup();  // false for hooks / private updater workers
  UpdateBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~UpdateBridge();
  bool HandleMessage(UINT message);
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
#endif
