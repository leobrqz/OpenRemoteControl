#include "../update_policy.h"
#include <fstream>
#include <iostream>

void Require(bool condition) { if (!condition) throw std::runtime_error("test failed"); }
template<class F> void Reject(F action) {
  bool rejected = false; try { action(); } catch (const std::exception&) { rejected = true; }
  Require(rejected);
}
int Run() {
  using namespace updater;
  const auto filename = std::string(kPackageId) + "-0.3.1-win-x64-full.nupkg";
  Validate(kPackageId, "0.3.1", "0.3.0", "Full", filename, std::string(64,'a'), 1024);
  for (const auto* version : {"0.3.0","0.2.1","0.3.1-beta","invalid","00.3.1"})
    Reject([&] { Validate(kPackageId, version, "0.3.0", "Full", filename, std::string(64,'a'), 1024); });
  Reject([&] { Validate("other", "0.3.1", "0.3.0", "Full", filename, std::string(64,'a'), 1024); });
  Reject([&] { Validate(kPackageId, "0.3.1", "0.3.0", "Delta", filename, std::string(64,'a'), 1024); });
  Reject([&] { Validate(kPackageId, "0.3.1", "0.3.0", "Full", "../evil.nupkg", "bad", 0); });
  Require(RequiredSpace(100, 200) == 100ULL * 1024 * 1024 + 400);
  Require(ErrorCode("HTTP 403 Forbidden", "check") == "rate_limited");
  Require(ErrorCode("sha256 checksum mismatch", "download") == "checksum");
  Require(ErrorCode("Network error: Http error: io: Peer disconnected", "download") == "checksum");
  Require(ErrorCode("could not find asset", "check") == "missing_asset");
  Require(ErrorCode("CreateProcess rejected", "prepareApply") == "prepare_failed");
  const auto base = std::filesystem::temp_directory_path() / (L"orc-policy-test-" + std::to_wstring(GetCurrentProcessId()));
  const auto root = base / L"\u00c1rea de Trabalho";
  std::filesystem::create_directories(root / L"current");
  Require(!std::filesystem::exists(root / L"packages"));
  Preflight(root, 1);
  Require(std::filesystem::is_directory(root / L"packages"));
  Preflight(root, 1); // Existing caches remain usable on later attempts.
  Reject([&] { Preflight(root, UINT64_MAX / 4); });
  std::filesystem::remove(root / L"packages");
  { std::ofstream blocker(root / L"packages"); blocker << "not a directory"; }
  bool blocked = false;
  try { Preflight(root, 1); }
  catch (const std::exception& error) {
    blocked = true;
    Require(ErrorCode(error.what(), "download") == "unwritable_directory");
    Require(std::string(error.what()).find("Windows error ") != std::string::npos);
    Require(std::string(error.what()).find((root / L"packages").u8string()) != std::string::npos);
  }
  Require(blocked);
  std::filesystem::remove(root / L"packages"); std::filesystem::remove(root / L"current");
  std::filesystem::remove(root); std::filesystem::remove(base);
  std::cout << "Native updater policy tests passed\n";
  return 0;
}
int main() {
  try { return Run(); }
  catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
