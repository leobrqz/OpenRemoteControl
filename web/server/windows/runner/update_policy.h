#pragma once
#include <array>
#include <cstdint>
#include <filesystem>
#include <regex>
#include <stdexcept>
#include <string>
#include <windows.h>

namespace updater {
constexpr char kPackageId[] = "org.openremotecontrol.windows";
constexpr char kChannel[] = "win-x64";
constexpr char kRepo[] = "https://github.com/leobrqz/OpenRemoteControl";

inline std::array<uint64_t, 3> Version(const std::string& text) {
  static const std::regex pattern("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");
  std::smatch parts;
  if (!std::regex_match(text, parts, pattern)) throw std::runtime_error("invalid_metadata");
  return {std::stoull(parts[1]), std::stoull(parts[2]), std::stoull(parts[3])};
}
inline void Validate(const std::string& id, const std::string& version,
                     const std::string& current, const std::string& type,
                     const std::string& filename, const std::string& hash, uint64_t size) {
  if (id != kPackageId || type != "Full" || Version(version) <= Version(current) ||
      filename != std::string(kPackageId) + "-" + version + "-" + kChannel + "-full.nupkg" ||
      !std::regex_match(hash, std::regex("^[a-fA-F0-9]{64}$")) || size == 0) {
    throw std::runtime_error("invalid_metadata");
  }
}
inline uint64_t RequiredSpace(uint64_t package, uint64_t application) {
  constexpr uint64_t reserve = 100ULL * 1024 * 1024;
  if (package > (UINT64_MAX - application - reserve) / 2)
    throw std::runtime_error("invalid_metadata");
  return 2 * package + application + reserve;
}
inline void Preflight(const std::filesystem::path& root, uint64_t package) {
  const auto current = root / L"current";
  uint64_t size = 0;
  for (const auto& entry : std::filesystem::recursive_directory_iterator(current)) {
    if (entry.is_regular_file()) size += entry.file_size();
    if (entry.is_symlink()) throw std::runtime_error("unwritable_directory");
  }
  for (const auto& directory : {root, current, root / L"packages"}) {
    const auto probe = directory / (L".orc-write-" + std::to_wstring(GetCurrentProcessId()));
    HANDLE file = CreateFileW(probe.c_str(), GENERIC_WRITE | DELETE, 0, nullptr,
                             CREATE_NEW, FILE_ATTRIBUTE_TEMPORARY | FILE_FLAG_DELETE_ON_CLOSE, nullptr);
    if (file == INVALID_HANDLE_VALUE) throw std::runtime_error("unwritable_directory");
    CloseHandle(file);
  }
  ULARGE_INTEGER available{};
  if (!GetDiskFreeSpaceExW(root.c_str(), &available, nullptr, nullptr) ||
      available.QuadPart < RequiredSpace(package, size)) {
    throw std::runtime_error("insufficient_space");
  }
}
inline std::string ErrorCode(std::string text, const std::string& operation) {
  for (auto& ch : text) ch = static_cast<char>(tolower(static_cast<unsigned char>(ch)));
  for (const auto* code : {"insufficient_space", "unwritable_directory", "invalid_metadata", "timeout"})
    if (text.find(code) != std::string::npos) return code;
  if (text.find("checksum") != std::string::npos || text.find("sha256") != std::string::npos ||
      text.find("size mismatch") != std::string::npos || text.find("unexpected eof") != std::string::npos ||
      (operation == "download" && text.find("peer disconnected") != std::string::npos))
    return "checksum";
  if (text.find("403") != std::string::npos || text.find("429") != std::string::npos) return "rate_limited";
  if (text.find("asset") != std::string::npos || text.find("404") != std::string::npos ||
      text.find("release feed") != std::string::npos) return "missing_asset";
  if (text.find("json") != std::string::npos || text.find("parse") != std::string::npos) return "invalid_metadata";
  return operation == "prepareApply" ? "prepare_failed" : "offline";
}
}
