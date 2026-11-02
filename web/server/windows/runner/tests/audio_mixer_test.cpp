#include <windows.h>
#include <audioclient.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <cmath>
#include <cstdio>
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

extern "C" __declspec(dllexport) const char* MixerFailure() {
  return failure.c_str();
}
