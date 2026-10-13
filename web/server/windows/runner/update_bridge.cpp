#include "update_bridge.h"
#include "update_policy.h"
#include <Velopack.hpp>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/standard_message_codec.h>
#include <flutter/event_stream_handler_functions.h>
#include <shellapi.h>
#include <algorithm>
#include <winhttp.h>
#include <json.hpp>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <fstream>
#include <functional>
#include <mutex>
#include <thread>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
constexpr UINT kReply = WM_APP + 71;
std::filesystem::path Executable() {
  wchar_t buffer[32768];
  const auto length = GetModuleFileNameW(nullptr, buffer, 32768);
  return std::filesystem::path(std::wstring(buffer, length));
}
std::string ReadFileText(const std::filesystem::path& path) {
  std::ifstream file(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
}
std::string CleanString(std::string value) {
  while (!value.empty() && value.back() == '\0') value.pop_back();
  return value;
}
void Log(const std::string& message) noexcept {
  try {
    wchar_t local[32768];
    if (!GetEnvironmentVariableW(L"LOCALAPPDATA", local, 32768)) return;
    auto directory = std::filesystem::path(local) / L"OpenRemoteControl" / L"logs";
    std::filesystem::create_directories(directory);
    HANDLE file = CreateFileW((directory / L"open-remote.log").c_str(), FILE_APPEND_DATA,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    SYSTEMTIME time{};
    GetLocalTime(&time);
    char date[64];
    snprintf(date, sizeof(date), "%04u-%02u-%02uT%02u:%02u:%02u", time.wYear, time.wMonth,
             time.wDay, time.wHour, time.wMinute, time.wSecond);
    const auto line = "[" + std::string(date) + "] [WindowsUpdater] " + message + "\n";
    DWORD written;
    WriteFile(file, line.data(), static_cast<DWORD>(line.size()), &written, nullptr);
    CloseHandle(file);
  } catch (...) {}
}
void Logger(void*, const char* level, const char* message) {
  // SDK trace includes complete package hexdumps. Keep useful diagnostics bounded.
  if (strcmp(level, "trace") == 0 || strcmp(level, "debug") == 0) return;
  Log(std::string(level) + ": " + message);
}
void ImportUpdaterLog() noexcept {
  try {
    wchar_t local[32768];
    if (!GetEnvironmentVariableW(L"LOCALAPPDATA", local, 32768)) return;
    const auto base = std::filesystem::path(local);
    const auto path = base / L"velopack" / L"velopack_org.openremotecontrol.windows.log";
    const auto cursor = base / L"OpenRemoteControl" / L"logs" / L"velopack.offset";
    if (!std::filesystem::exists(path)) return;
    uint64_t offset = 0;
    std::ifstream saved(cursor); saved >> offset;
    const auto size = std::filesystem::file_size(path);
    if (offset > size) offset = 0;
    if (size - offset > 256 * 1024) offset = size - 256 * 1024;
    std::ifstream file(path, std::ios::binary); file.seekg(offset);
    std::string line;
    while (std::getline(file, line)) Log("Velopack: " + line);
    std::ofstream next(cursor, std::ios::trunc); next << size;
  } catch (...) {}
}

// Framed StandardMessageCodec IPC stays native. No URLs / paths cross the Dart API.
void Write(HANDLE pipe, const Value& value) {
  const auto bytes = flutter::StandardMessageCodec::GetInstance().EncodeMessage(value);
  const uint32_t length = static_cast<uint32_t>(bytes->size());
  DWORD written;
  if (!WriteFile(pipe, &length, sizeof(length), &written, nullptr)) throw std::runtime_error("worker_closed");
  size_t offset = 0;
  while (offset < bytes->size()) {
    if (!WriteFile(pipe, bytes->data() + offset, static_cast<DWORD>(bytes->size() - offset), &written, nullptr) || written == 0)
      throw std::runtime_error("worker_closed");
    offset += written;
  }
}
bool ReadBytes(HANDLE pipe, uint8_t* bytes, size_t count, ULONGLONG deadline = UINT64_MAX) {
  size_t offset = 0;
  while (offset < count) {
    if (GetTickCount64() >= deadline) throw std::runtime_error("timeout");
    DWORD available;
    if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr)) return false;
    if (!available) { Sleep(10); continue; }
    DWORD read;
    if (!ReadFile(pipe, bytes + offset, static_cast<DWORD>(std::min<size_t>(available, count - offset)), &read, nullptr) || !read) return false;
    offset += read;
  }
  return true;
}
std::unique_ptr<Value> Read(HANDLE pipe, ULONGLONG deadline = UINT64_MAX) {
  uint32_t length = 0;
  if (!ReadBytes(pipe, reinterpret_cast<uint8_t*>(&length), sizeof(length), deadline)) return nullptr;
  if (length > 1024 * 1024) throw std::runtime_error("invalid_metadata");
  std::vector<uint8_t> bytes(length);
  if (!ReadBytes(pipe, bytes.data(), length, deadline)) return nullptr;
  return flutter::StandardMessageCodec::GetInstance().DecodeMessage(bytes.data(), bytes.size());
}
std::string String(const Map& map, const char* key) { return std::get<std::string>(map.at(Value(key))); }

std::string Channel(const std::filesystem::path& current) {
  const auto manifest = ReadFileText(current / L"sq.version");
  const std::string start = "<channel>";
  const auto pos = manifest.find(start);
  const auto end = manifest.find("</channel>", pos);
  return pos == std::string::npos || end == std::string::npos ? "" : manifest.substr(pos + start.size(), end - pos - start.size());
}
void RestorePackages(const std::filesystem::path& packages) {
  if (!std::filesystem::is_directory(packages)) return;
  for (const auto& entry : std::filesystem::directory_iterator(packages)) {
    if (entry.path().extension() == L".retained") {
      auto original = entry.path(); original.replace_extension();
      if (!std::filesystem::exists(original)) std::filesystem::rename(entry.path(), original);
    }
  }
}

struct HttpHandle {
  HINTERNET handle;
  ~HttpHandle() { if (handle) WinHttpCloseHandle(handle); }
};
std::optional<std::string> LatestGithubVersion(const std::string& current) {
  HttpHandle session{WinHttpOpen(L"OpenRemoteControl/" ORC_PRODUCT_VERSION,
      WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0)};
  if (!session.handle) throw std::runtime_error("offline");
  WinHttpSetTimeouts(session.handle, 30000, 30000, 30000, 30000);
  HttpHandle connection{WinHttpConnect(session.handle, L"api.github.com", INTERNET_DEFAULT_HTTPS_PORT, 0)};
  HttpHandle request{WinHttpOpenRequest(connection.handle, L"GET", L"/repos/leobrqz/OpenRemoteControl/releases/latest",
      nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, WINHTTP_FLAG_SECURE)};
  if (!request.handle || !WinHttpSendRequest(request.handle, L"Accept: application/vnd.github+json\r\n", static_cast<DWORD>(-1),
      WINHTTP_NO_REQUEST_DATA, 0, 0, 0) || !WinHttpReceiveResponse(request.handle, nullptr))
    throw std::runtime_error(GetLastError() == ERROR_WINHTTP_TIMEOUT ? "timeout" : "offline");
  DWORD status = 0, size = sizeof(status);
  WinHttpQueryHeaders(request.handle, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
      WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX);
  if (status != 200) throw std::runtime_error("GitHub HTTP " + std::to_string(status));
  std::string body;
  char buffer[8192]; DWORD read;
  do {
    if (!WinHttpReadData(request.handle, buffer, sizeof(buffer), &read)) throw std::runtime_error("offline");
    body.append(buffer, read);
    if (body.size() > 1024 * 1024) throw std::runtime_error("invalid_metadata");
  } while (read);
  const auto release = nlohmann::json::parse(body);
  const auto tag = release.at("tag_name").get<std::string>();
  if (release.at("draft").get<bool>() || release.at("prerelease").get<bool>() || tag.empty() || tag[0] != 'v')
    throw std::runtime_error("invalid_metadata");
  const auto version = tag.substr(1);
  if (updater::Version(version) <= updater::Version(current)) return std::nullopt;
  bool feed = false, package = false;
  const auto packageName = std::string(updater::kPackageId) + "-" + version + "-win-x64-full.nupkg";
  for (const auto& asset : release.at("assets")) {
    const auto name = asset.at("name").get<std::string>();
    if (name == "releases.win-x64.json") feed = asset.at("size").get<uint64_t>() > 0;
    if (name == packageName) package = asset.at("size").get<uint64_t>() > 0;
  }
  if (!feed || !package) throw std::runtime_error("missing_asset");
  return version;
}

void Worker(DWORD parent) {
  const auto input = GetStdHandle(STD_INPUT_HANDLE);
  const auto output = GetStdHandle(STD_OUTPUT_HANDLE);
  const auto current = Executable().parent_path();
  const auto root = current.parent_path();
  const auto packages = root / L"packages";
  std::unique_ptr<Velopack::UpdateManager> manager;
  std::optional<Velopack::UpdateInfo> candidate;
  bool downloaded = false;
  std::string version = ORC_PRODUCT_VERSION;
  std::string channel = Channel(current);
  bool testSource = false;
  try {
    RestorePackages(packages);
    Velopack::UpdateOptions options{false, std::string(updater::kChannel), -1};
#ifdef ORC_UPDATER_TESTING
    wchar_t source[32768];
    if (GetEnvironmentVariableW(L"ORC_UPDATER_TEST_SOURCE", source, 32768)) {
      testSource = true;
      const auto value = std::filesystem::path(source).u8string();
      if (value.rfind("http://127.0.0.1:", 0) == 0) {
        manager = std::make_unique<Velopack::UpdateManager>(
            std::make_unique<Velopack::HttpSource>(value, Velopack::HttpOptions{{}, 300000}), &options);
      } else {
        manager = std::make_unique<Velopack::UpdateManager>(
            std::make_unique<Velopack::FileSource>(value), &options);
      }
    } else
#endif
    {
      manager = std::make_unique<Velopack::UpdateManager>(
          std::make_unique<Velopack::GithubSource>(updater::kRepo, "", false), &options);
    }
    version = CleanString(manager->GetCurrentVersion());
  } catch (const std::exception& error) { Log(error.what()); }
  const bool managed = manager && manager->IsPortable() &&
      CleanString(manager->GetAppId()) == updater::kPackageId && channel == updater::kChannel;
  while (auto command = Read(input)) {
    const auto operation = std::get<std::string>(*command);
    try {
      Value result;
      if (operation == "getContext") {
        result = Map{{Value("version"), Value(version)}, {Value("managed"), Value(managed)},
          {Value("packageId"), Value(updater::kPackageId)}, {Value("channel"), Value(channel)}};
      } else {
        if (!managed) throw std::runtime_error("disabled");
        if (operation == "check") {
          candidate.reset(); downloaded = false;
#ifdef ORC_UPDATER_TESTING
          wchar_t delay[32];
          if (GetEnvironmentVariableW(L"ORC_UPDATER_TEST_DELAY", delay, 32)) Sleep(static_cast<DWORD>(_wtoi(delay)));
#endif
          const auto latest = testSource ? std::optional<std::string>() : LatestGithubVersion(version);
          if (testSource || latest) candidate = manager->CheckForUpdates();
          if (latest && (!candidate || candidate->TargetFullRelease.Version != *latest)) throw std::runtime_error("invalid_metadata");
          if (candidate) {
            auto& asset = candidate->TargetFullRelease;
            updater::Validate(asset.PackageId, asset.Version, version, asset.Type, asset.FileName, asset.SHA256, asset.Size);
            if (asset.NotesMarkdown.size() > 65536) throw std::runtime_error("invalid_metadata");
            result = Map{{Value("version"), Value(asset.Version)}, {Value("packageId"), Value(asset.PackageId)},
              {Value("channel"), Value(updater::kChannel)}, {Value("notes"), Value(asset.NotesMarkdown)},
              {Value("releaseUrl"), Value(std::string(updater::kRepo) + "/releases/tag/v" + asset.Version)}};
          }
        } else if (operation == "download") {
          if (!candidate || downloaded) throw std::runtime_error("invalid_state");
          updater::Preflight(root, candidate->TargetFullRelease.Size);
#ifdef ORC_UPDATER_TESTING
          wchar_t delay[32];
          if (GetEnvironmentVariableW(L"ORC_UPDATER_TEST_DOWNLOAD_DELAY", delay, 32)) Sleep(static_cast<DWORD>(_wtoi(delay)));
#endif
          // SDK 1.2.161 deletes older *.nupkg during download. Protect the installed full
          // package until validation completes, including worker timeout / crash recovery.
          const auto prior = packages / (std::string(updater::kPackageId) + "-" + version + "-" + updater::kChannel + "-full.nupkg");
          if (std::filesystem::exists(prior)) std::filesystem::rename(prior, prior.wstring() + L".retained");
          try {
            manager->DownloadUpdates(*candidate, [](void* data, size_t percent) {
              try {
                Write(*static_cast<HANDLE*>(data), Value(Map{{Value("type"), Value("progress")},
                    {Value("percent"), Value(static_cast<int32_t>(std::min<size_t>(percent, 100)))}}));
              } catch (...) { /* Never unwind through the SDK's C callback. */ }
            }, const_cast<HANDLE*>(&output));
            RestorePackages(packages);
            downloaded = true;
          } catch (...) { RestorePackages(packages); throw; }
        } else if (operation == "prepareApply") {
          if (!candidate || !downloaded) throw std::runtime_error("invalid_state");
          updater::Preflight(root, candidate->TargetFullRelease.Size);
#ifdef ORC_UPDATER_TESTING
          if (GetEnvironmentVariableW(L"ORC_UPDATER_TEST_PREPARE_FAIL", nullptr, 0)) throw std::runtime_error("prepare_failed");
#endif
          // The SDK worker is a different process. Wait for the known host PID, not
          // this worker, so replacement begins only after graceful host shutdown.
          manager->UnsafeApplyUpdates(candidate->TargetFullRelease, true, parent, true, {"--background"});
        } else throw std::runtime_error("invalid_state");
      }
      Write(output, Value(Map{{Value("type"), Value("result")}, {Value("value"), result}}));
      if (operation == "prepareApply") return;
    } catch (const std::exception& error) {
      const auto code = updater::ErrorCode(error.what(), operation);
      Log(operation + ": " + error.what());
      candidate.reset(); downloaded = false;
      Write(output, Value(Map{{Value("type"), Value("error")}, {Value("code"), Value(code)}, {Value("message"), Value(error.what())}}));
    }
  }
}
}

bool UpdateBridge::RunStartup() {
  try {
    Velopack::VelopackApp::Build().SetLogger(Logger, nullptr).SetAutoApplyOnStartup(false).Run();
    int count = 0;
    auto args = CommandLineToArgvW(GetCommandLineW(), &count);
    const bool worker = count == 3 && std::wstring(args[1]) == L"--orc-updater-worker";
    const DWORD parent = worker ? static_cast<DWORD>(_wcstoui64(args[2], nullptr, 10)) : 0;
    LocalFree(args);
    if (worker) { Worker(parent); return false; }
    // Velopack fast hooks normally exit in Run; never start Flutter for a hook.
    if (std::wstring(GetCommandLineW()).find(L"--veloapp-") != std::wstring::npos) return false;
    ImportUpdaterLog();
    return true;
  } catch (const std::exception& error) { Log(std::string("startup: ") + error.what()); return false; }
}

struct UpdateBridge::Impl {
  HWND window;
  std::unique_ptr<flutter::MethodChannel<Value>> methods;
  std::unique_ptr<flutter::EventChannel<Value>> events;
  std::unique_ptr<flutter::EventSink<Value>> sink;
  std::mutex mutex;
  std::condition_variable ready;
  std::deque<std::function<void()>> work;
  std::deque<std::function<void()>> replies;
  bool stopping = false;
  bool busy = false;
  std::thread thread;
  HANDLE process = nullptr, input = nullptr, output = nullptr;

  void Post(std::function<void()> reply) {
    { std::lock_guard<std::mutex> lock(mutex); replies.push_back(std::move(reply)); }
    PostMessageW(window, kReply, 0, 0);
  }
  void StopWorker() {
    if (process) {
      TerminateProcess(process, 0);
      WaitForSingleObject(process, 2000);
      CloseHandle(process); process = nullptr;
    }
    if (input) { CloseHandle(input); input = nullptr; }
    if (output) { CloseHandle(output); output = nullptr; }
  }
  void StartWorker() {
    if (process && WaitForSingleObject(process, 0) == WAIT_TIMEOUT) return;
    StopWorker();
    SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
    HANDLE childInput = nullptr, childOutput = nullptr;
    if (!CreatePipe(&childInput, &input, &security, 0) || !CreatePipe(&output, &childOutput, &security, 0))
      throw std::runtime_error("worker_start_failed");
    SetHandleInformation(input, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(output, HANDLE_FLAG_INHERIT, 0);
    STARTUPINFOEXW startup{};
    startup.StartupInfo.cb = sizeof(startup);
    startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
    startup.StartupInfo.wShowWindow = SW_HIDE;
    startup.StartupInfo.hStdInput = childInput;
    startup.StartupInfo.hStdOutput = childOutput;
    startup.StartupInfo.hStdError = childOutput;
    SIZE_T bytes = 0;
    InitializeProcThreadAttributeList(nullptr, 1, 0, &bytes);
    std::vector<uint8_t> storage(bytes);
    startup.lpAttributeList = reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(storage.data());
    InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0, &bytes);
    HANDLE inherited[] = {childInput, childOutput};
    UpdateProcThreadAttribute(startup.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                              inherited, sizeof(inherited), nullptr, nullptr);
    const auto executable = Executable();
    auto command = L"\"" + executable.wstring() + L"\" --orc-updater-worker " + std::to_wstring(GetCurrentProcessId());
    PROCESS_INFORMATION info{};
    const bool created = CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, TRUE,
        CREATE_NO_WINDOW | EXTENDED_STARTUPINFO_PRESENT, nullptr, executable.parent_path().c_str(), &startup.StartupInfo, &info);
    DeleteProcThreadAttributeList(startup.lpAttributeList);
    CloseHandle(childInput); CloseHandle(childOutput);
    if (!created) { StopWorker(); throw std::runtime_error("worker_start_failed"); }
    process = info.hProcess; CloseHandle(info.hThread);
  }

  Impl(flutter::BinaryMessenger* messenger, HWND hwnd) : window(hwnd) {
    methods = std::make_unique<flutter::MethodChannel<Value>>(messenger, "open_remote/updater", &flutter::StandardMethodCodec::GetInstance());
    events = std::make_unique<flutter::EventChannel<Value>>(messenger, "open_remote/updater_events", &flutter::StandardMethodCodec::GetInstance());
    events->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<Value>>(
      [this](const Value*, std::unique_ptr<flutter::EventSink<Value>> value) { sink = std::move(value); return nullptr; },
      [this](const Value*) { sink.reset(); return nullptr; }));
    methods->SetMethodCallHandler([this](const flutter::MethodCall<Value>& call, std::unique_ptr<flutter::MethodResult<Value>> reply) {
      const auto operation = call.method_name();
      if (operation != "getContext" && operation != "check" && operation != "download" && operation != "prepareApply") { reply->NotImplemented(); return; }
      if (call.arguments() && !std::holds_alternative<std::monostate>(*call.arguments())) { reply->Error("invalid_arguments", "Updater takes no arguments."); return; }
      const auto result = std::shared_ptr<flutter::MethodResult<Value>>(std::move(reply));
      std::lock_guard<std::mutex> lock(mutex);
      if (busy) { result->Error("busy", "Updater operation already running."); return; }
      busy = true;
      work.push_back([this, result, operation] {
        try {
          StartWorker();
          Write(input, Value(operation));
          auto timeout = operation == "download" ? 300000ULL : 30000ULL;
#ifdef ORC_UPDATER_TESTING
          wchar_t duration[32];
          if (GetEnvironmentVariableW(L"ORC_UPDATER_TEST_TIMEOUT", duration, 32)) timeout = _wcstoui64(duration, nullptr, 10);
#endif
          const auto deadline = GetTickCount64() + timeout;
          while (auto message = Read(output, deadline)) {
            const auto& map = std::get<Map>(*message);
            const auto type = String(map, "type");
            if (type == "progress") { Post([this, value = *message] { if (sink) sink->Success(value); }); continue; }
            { std::lock_guard<std::mutex> guard(mutex); busy = false; }
            if (type == "error") {
              const auto code = String(map, "code"), detail = String(map, "message");
              Post([this, result, code, detail] {
                if (sink) sink->Success(Value(Map{{Value("type"), Value("error")}, {Value("code"), Value(code)}}));
                result->Error(code, detail);
              });
            } else { Post([result, value = map.at(Value("value"))] { result->Success(value); }); }
            return;
          }
          throw std::runtime_error("worker_closed");
        } catch (const std::exception& error) {
          StopWorker();
          const auto code = updater::ErrorCode(error.what(), operation), detail = std::string(error.what());
          Log(operation + ": " + detail);
          { std::lock_guard<std::mutex> guard(mutex); busy = false; }
          Post([this, result, code, detail] {
            if (sink) sink->Success(Value(Map{{Value("type"), Value("error")}, {Value("code"), Value(code)}}));
            result->Error(code, detail);
          });
        }
      });
      ready.notify_one();
    });
    thread = std::thread([this] {
      while (true) {
        std::function<void()> task;
        { std::unique_lock<std::mutex> lock(mutex); ready.wait(lock, [this] { return stopping || !work.empty(); });
          if (stopping) break; task = std::move(work.front()); work.pop_front(); }
        task();
      }
      StopWorker();
    });
  }
  ~Impl() {
    methods->SetMethodCallHandler(nullptr); events->SetStreamHandler(nullptr);
    { std::lock_guard<std::mutex> lock(mutex); stopping = true; }
    // Cancel pending HTTP before joining; platform teardown never waits on the network.
    if (process) TerminateProcess(process, 0);
    ready.notify_one(); thread.join();
  }
};
UpdateBridge::UpdateBridge(flutter::BinaryMessenger* messenger, HWND window) : impl_(std::make_unique<Impl>(messenger, window)) {}
UpdateBridge::~UpdateBridge() = default;
bool UpdateBridge::HandleMessage(UINT message) {
  if (message != kReply) return false;
  std::deque<std::function<void()>> replies;
  { std::lock_guard<std::mutex> lock(impl_->mutex); replies.swap(impl_->replies); }
  for (const auto& reply : replies) reply();
  return true;
}
