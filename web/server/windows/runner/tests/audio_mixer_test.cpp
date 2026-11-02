#include <windows.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>
#include <vector>

#include "../audio_mixer.h"
#include "../audio_volume.h"

using Microsoft::WRL::ComPtr;
static std::string failure;

static bool Check(HRESULT status, const char* step) {
  if (SUCCEEDED(status)) return true;
  char message[128];
  sprintf_s(message, "%s failed: 0x%08lx", step, static_cast<unsigned long>(status));
  failure = message;
  return false;
}

static bool RunProbe() {
  OutputVolume original{};
  if (!Check(ReadDefaultOutputVolume(&original), "read master")) return false;
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (!Check(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(enumerator.GetAddressOf())), "enumerator")) return false;
  ComPtr<IMMDevice> device;
  if (!Check(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, device.GetAddressOf()),
             "default device")) return false;
  GUID grouping;
  if (!Check(CoCreateGuid(&grouping), "group guid")) return false;
  std::vector<ComPtr<IAudioClient>> clients;
  std::vector<ComPtr<IAudioSessionControl>> controls;
  std::vector<ComPtr<ISimpleAudioVolume>> volumes;
  for (int i = 0; i < 2; ++i) {
    ComPtr<IAudioClient> client;
    if (!Check(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                reinterpret_cast<void**>(client.GetAddressOf())), "audio client")) return false;
    WAVEFORMATEX* format = nullptr;
    if (!Check(client->GetMixFormat(&format), "mix format")) return false;
    GUID session;
    CoCreateGuid(&session);
    HRESULT status = client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 10000000,
                                         0, format, &session);
    CoTaskMemFree(format);
    if (!Check(status, "initialize session")) return false;
    ComPtr<IAudioSessionControl> control;
    ComPtr<ISimpleAudioVolume> volume;
    if (!Check(client->GetService(IID_PPV_ARGS(control.GetAddressOf())), "session control") ||
        !Check(client->GetService(IID_PPV_ARGS(volume.GetAddressOf())), "simple volume") ||
        !Check(control->SetDisplayName(L"Open Remote Mixer Test", nullptr), "display name") ||
        !Check(control->SetGroupingParam(&grouping, nullptr), "set grouping") ||
        !Check(volume->SetMasterVolume(0.37f, nullptr), "initial volume")) return false;
    clients.push_back(client);
    controls.push_back(control);
    volumes.push_back(volume);
  }
  AudioMixer mixer;
  std::vector<MixerSession> found;
  if (!Check(mixer.Read(&found), "read mixer")) return false;
  std::string id;
  int matches = 0;
  for (const auto& item : found) {
    if (item.name == "Open Remote Mixer Test") {
      ++matches;
      id = item.id;
      if (item.level != 37 || item.muted) { failure = "wrong initial session state"; return false; }
    }
  }
  if (matches != 1) { failure = "grouped sessions did not produce one mixer entry"; return false; }
  if (mixer.SetLevel(id, 62) != S_OK || mixer.SetMute(id, true) != S_OK) {
    failure = "mixer failed to update group";
    return false;
  }
  for (const auto& volume : volumes) {
    float level = 0;
    BOOL muted = FALSE;
    if (!Check(volume->GetMasterVolume(&level), "read session level") ||
        !Check(volume->GetMute(&muted), "read session mute")) return false;
    if (std::abs(level - 0.62f) > 0.001f || !muted) {
      failure = "group update did not affect both sessions";
      return false;
    }
  }
  GUID another_group;
  CoCreateGuid(&another_group);
  if (!Check(controls[1]->SetGroupingParam(&another_group, nullptr), "change grouping")) return false;
  if (mixer.SetLevel(id, 70) != S_OK) { failure = "stale grouping update failed"; return false; }
  float unchanged = 0;
  if (!Check(volumes[1]->GetMasterVolume(&unchanged), "read regrouped session") ||
      std::abs(unchanged - 0.62f) > 0.001f) {
    failure = "stale command modified a regrouped session";
    return false;
  }
  if (!Check(mixer.Read(&found), "read regrouped mixer")) return false;
  matches = 0;
  for (const auto& item : found) if (item.name == "Open Remote Mixer Test") ++matches;
  if (matches != 2) { failure = "regrouped sessions did not separate"; return false; }
  OutputVolume after{};
  if (!Check(ReadDefaultOutputVolume(&after), "read unchanged master") ||
      after.level != original.level || after.muted != original.muted) {
    failure = "master volume changed";
    return false;
  }
  return true;
}

extern "C" __declspec(dllexport) int TestMixer() {
  bool ok = false;
  std::thread worker([&] {
    HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (!Check(init, "initialize COM")) return;
    ok = RunProbe();
    CoUninitialize();
  });
  worker.join();
  return ok ? 1 : 0;
}

// The other process owns the stream. This distinguishes a real application
// closing from releasing a stream created by this same test process.
static bool RunFixture(const char* session_name, HANDLE ready, HANDLE stop) {
  ComPtr<IMMDeviceEnumerator> enumerator;
  if (!Check(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                              IID_PPV_ARGS(enumerator.GetAddressOf())), "fixture enumerator")) return false;
  ComPtr<IMMDevice> device;
  if (!Check(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, device.GetAddressOf()),
             "fixture device")) return false;
  ComPtr<IAudioClient> client;
  if (!Check(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                              reinterpret_cast<void**>(client.GetAddressOf())), "fixture client")) return false;
  WAVEFORMATEX* format = nullptr;
  if (!Check(client->GetMixFormat(&format), "fixture format")) return false;
  GUID session;
  CoCreateGuid(&session);
  const HRESULT status = client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 10000000,
                                             0, format, &session);
  CoTaskMemFree(format);
  if (!Check(status, "fixture stream")) return false;
  ComPtr<IAudioSessionControl> control;
  ComPtr<ISimpleAudioVolume> volume;
  if (!Check(client->GetService(IID_PPV_ARGS(control.GetAddressOf())), "fixture control") ||
      !Check(client->GetService(IID_PPV_ARGS(volume.GetAddressOf())), "fixture volume")) return false;
  const std::wstring name(session_name, session_name + strlen(session_name));
  if (!Check(control->SetDisplayName(name.c_str(), nullptr), "fixture name") ||
      !Check(volume->SetMasterVolume(0.37f, nullptr), "fixture level")) return false;
  SetEvent(ready);
  return WaitForSingleObject(stop, 30000) == WAIT_OBJECT_0;
}

extern "C" __declspec(dllexport) int AudioMixerFixture(
    const char* session_name, const char* ready_name, const char* stop_name,
    const char* done_name) {
  const HANDLE ready = OpenEventA(EVENT_MODIFY_STATE, FALSE, ready_name);
  const HANDLE stop = OpenEventA(SYNCHRONIZE, FALSE, stop_name);
  const HANDLE done = OpenEventA(EVENT_MODIFY_STATE, FALSE, done_name);
  if (!ready || !stop || !done) return 0;
  bool ok = false;
  std::thread worker([&] {
    const HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (SUCCEEDED(init)) {
      ok = RunFixture(session_name, ready, stop);
      CoUninitialize();
    }
    SetEvent(done);
  });
  worker.join();
  CloseHandle(ready);
  CloseHandle(stop);
  CloseHandle(done);
  return ok ? 1 : 0;
}

static bool RunCrossProcess(const char* session_name, HANDLE stop, HANDLE done) {
  AudioMixer mixer;
  std::vector<MixerSession> sessions;
  if (!Check(mixer.Read(&sessions), "read fixture session")) return false;
  std::string id;
  for (const auto& session : sessions) {
    if (session.name == session_name) id = session.id;
  }
  if (id.empty()) { failure = "external session was not listed"; return false; }
  if (mixer.SetLevel(id, 59) != S_OK || mixer.SetMute(id, true) != S_OK) {
    failure = "external session did not accept changes";
    return false;
  }
  if (!Check(mixer.Read(&sessions), "verify fixture session")) return false;
  bool updated = false;
  for (const auto& session : sessions) {
    if (session.id == id && session.level == 59 && session.muted) updated = true;
  }
  if (!updated) { failure = "external session did not reflect changes"; return false; }
  SetEvent(stop);
  if (WaitForSingleObject(done, 10000) != WAIT_OBJECT_0) {
    failure = "external audio process did not stop";
    return false;
  }
  bool removed = false;
  for (int attempt = 0; attempt < 40; ++attempt) {
    Sleep(50);
    if (!Check(mixer.Read(&sessions), "read closed fixture session")) return false;
    removed = true;
    for (const auto& session : sessions) {
      if (session.name == session_name) removed = false;
    }
    if (removed) break;
  }
  if (!removed) { failure = "closed external session remained in the mixer"; return false; }
  if (mixer.SetLevel(id, 10) != S_FALSE) {
    failure = "closed external session accepted a stale command";
    return false;
  }
  return true;
}

extern "C" __declspec(dllexport) int TestMixerAcrossProcesses(
    const char* session_name, const char* stop_name, const char* done_name) {
  const HANDLE stop = OpenEventA(EVENT_MODIFY_STATE, FALSE, stop_name);
  const HANDLE done = OpenEventA(SYNCHRONIZE, FALSE, done_name);
  if (!stop || !done) { failure = "could not open test events"; return 0; }
  bool ok = false;
  std::thread worker([&] {
    const HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (!Check(init, "initialize cross-process COM")) return;
    ok = RunCrossProcess(session_name, stop, done);
    CoUninitialize();
  });
  worker.join();
  CloseHandle(stop);
  CloseHandle(done);
  return ok ? 1 : 0;
}

extern "C" __declspec(dllexport) const char* MixerFailure() {
  return failure.c_str();
}
