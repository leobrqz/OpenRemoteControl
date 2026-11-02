#include "audio_mixer.h"

#include <audioclient.h>
#include <audiopolicy.h>
#include <mmdeviceapi.h>
#include <propkey.h>
#include <shlwapi.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <map>
#include <set>
#include <utility>

namespace {
using Microsoft::WRL::ComPtr;

// PKEY_Device_FriendlyName, kept local so no SDK GUID library is required.
const PROPERTYKEY kFriendlyName = {
    {0xa45c254e, 0xdf1c, 0x4efd, {0x80, 0x20, 0x67, 0xd1, 0x46, 0xa8, 0x50, 0xe0}},
    14};

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                       value.data(), static_cast<int>(value.size()),
                                       nullptr, 0, nullptr, nullptr);
  if (size <= 0) return {};
  std::string result(size, '\0');
  if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
                           static_cast<int>(value.size()), result.data(), size,
                           nullptr, nullptr)) {
    return {};
  }
  return result;
}

std::wstring DeviceName(IMMDevice* device) {
  ComPtr<IPropertyStore> properties;
  if (FAILED(device->OpenPropertyStore(STGM_READ, properties.GetAddressOf()))) {
    return {};
  }
  PROPVARIANT value;
  PropVariantInit(&value);
  std::wstring name;
  if (SUCCEEDED(properties->GetValue(kFriendlyName, &value)) &&
      value.vt == VT_LPWSTR && value.pwszVal != nullptr) {
    name = value.pwszVal;
  }
  PropVariantClear(&value);
  return name;
}

std::wstring ProcessName(DWORD pid) {
  if (pid == 0) return {};
  HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) return {};
  std::wstring path(32768, L'\0');
  DWORD length = static_cast<DWORD>(path.size());
  const BOOL found = QueryFullProcessImageNameW(process, 0, path.data(), &length);
  CloseHandle(process);
  if (!found || length == 0) return {};
  path.resize(length);

  DWORD ignored = 0;
  const DWORD version_size = GetFileVersionInfoSizeW(path.c_str(), &ignored);
  if (version_size > 0 && version_size <= 1024 * 1024) {
    std::vector<BYTE> version(version_size);
    if (GetFileVersionInfoW(path.c_str(), 0, version_size, version.data())) {
      struct Translation { WORD language; WORD codepage; };
      Translation* translations = nullptr;
      UINT translation_size = 0;
      if (VerQueryValueW(version.data(), L"\\VarFileInfo\\Translation",
                         reinterpret_cast<void**>(&translations), &translation_size) &&
          translation_size >= sizeof(Translation)) {
        wchar_t key[64];
        swprintf_s(key, L"\\StringFileInfo\\%04x%04x\\FileDescription",
                   translations[0].language, translations[0].codepage);
        wchar_t* description = nullptr;
        UINT description_size = 0;
        if (VerQueryValueW(version.data(), key,
                           reinterpret_cast<void**>(&description), &description_size) &&
            description != nullptr && description_size > 1) {
          return description;
        }
      }
    }
  }
  const auto slash = path.find_last_of(L"\\/");
  std::wstring name = path.substr(slash == std::wstring::npos ? 0 : slash + 1);
  const auto dot = name.find_last_of(L'.');
  if (dot != std::wstring::npos) name.resize(dot);
  return name;
}

std::wstring SessionName(IAudioSessionControl2* control) {
  LPWSTR raw = nullptr;
  std::wstring name;
  if (SUCCEEDED(control->GetDisplayName(&raw)) && raw != nullptr) name = raw;
  CoTaskMemFree(raw);
  if (!name.empty() && name.front() == L'@') {
    wchar_t resolved[1024]{};
    if (SUCCEEDED(SHLoadIndirectString(name.c_str(), resolved,
                                       static_cast<UINT>(std::size(resolved)), nullptr))) {
      name = resolved;
    } else {
      name.clear();
    }
  }
  if (name.empty()) {
    DWORD pid = 0;
    if (SUCCEEDED(control->GetProcessId(&pid))) name = ProcessName(pid);
  }
  return name;
}

std::wstring GuidString(const GUID& value) {
  wchar_t buffer[40]{};
  return StringFromGUID2(value, buffer, static_cast<int>(std::size(buffer))) > 0
             ? std::wstring(buffer)
             : std::wstring();
}

struct LiveSession {
  ComPtr<IAudioSessionControl2> control;
  ComPtr<ISimpleAudioVolume> volume;
  GUID grouping{};
};

struct Group {
  MixerSession state;
  std::vector<LiveSession> sessions;
  bool has_active = false;
};
}  // namespace

struct AudioMixer::Impl {
  uint64_t next_id = 1;
  std::map<std::wstring, std::string> ids;
  std::map<std::string, std::vector<LiveSession>> live;

  template <typename Apply>
  HRESULT Set(const std::string& id, Apply apply) {
    const auto item = live.find(id);
    if (item == live.end()) return S_FALSE;
    bool changed = false;
    HRESULT last_error = S_OK;
    for (const auto& session : item->second) {
      AudioSessionState state;
      GUID grouping{};
      if (FAILED(session.control->GetState(&state)) ||
          state == AudioSessionStateExpired ||
          FAILED(session.control->GetGroupingParam(&grouping)) ||
          !IsEqualGUID(grouping, session.grouping)) {
        continue;
      }
      const HRESULT status = apply(session.volume.Get());
      if (SUCCEEDED(status)) changed = true;
      else last_error = status;
    }
    return changed ? S_OK : (FAILED(last_error) ? last_error : S_FALSE);
  }
};

AudioMixer::AudioMixer() : impl_(std::make_unique<Impl>()) {}
AudioMixer::~AudioMixer() = default;

HRESULT AudioMixer::Read(std::vector<MixerSession>* sessions) {
  if (sessions == nullptr) return E_POINTER;
  impl_->live.clear();
  ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT status = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                    CLSCTX_ALL,
                                    IID_PPV_ARGS(enumerator.GetAddressOf()));
  if (FAILED(status)) return status;
  ComPtr<IMMDeviceCollection> devices;
  status = enumerator->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE,
                                          devices.GetAddressOf());
  if (FAILED(status)) return status;
  UINT device_count = 0;
  if (FAILED(status = devices->GetCount(&device_count))) return status;

  std::map<std::wstring, Group> groups;
  UINT available_devices = 0;
  HRESULT last_error = E_FAIL;
  for (UINT d = 0; d < device_count; ++d) {
    ComPtr<IMMDevice> device;
    if (FAILED(status = devices->Item(d, device.GetAddressOf()))) {
      last_error = status;
      continue;
    }
    LPWSTR raw_id = nullptr;
    status = device->GetId(&raw_id);
    if (FAILED(status) || raw_id == nullptr) {
      CoTaskMemFree(raw_id);
      last_error = FAILED(status) ? status : E_FAIL;
      continue;
    }
    const std::wstring device_id(raw_id);
    CoTaskMemFree(raw_id);
    ComPtr<IAudioSessionManager2> manager;
    status = device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL,
                              nullptr, reinterpret_cast<void**>(manager.GetAddressOf()));
    if (FAILED(status)) { last_error = status; continue; }
    ComPtr<IAudioSessionEnumerator> list;
    if (FAILED(status = manager->GetSessionEnumerator(list.GetAddressOf()))) {
      last_error = status;
      continue;
    }
    int count = 0;
    if (FAILED(status = list->GetCount(&count))) { last_error = status; continue; }
    ++available_devices;
    const std::string device_name = ToUtf8(DeviceName(device.Get()));
    for (int i = 0; i < count; ++i) {
      ComPtr<IAudioSessionControl> base;
      if (FAILED(list->GetSession(i, base.GetAddressOf()))) continue;
      ComPtr<IAudioSessionControl2> control;
      ComPtr<ISimpleAudioVolume> volume;
      if (FAILED(base.As(&control)) || FAILED(base.As(&volume))) continue;
      AudioSessionState state;
      GUID grouping{};
      if (FAILED(control->GetState(&state)) || state == AudioSessionStateExpired ||
          FAILED(control->GetGroupingParam(&grouping))) continue;
      LPWSTR raw_session = nullptr;
      if (FAILED(control->GetSessionInstanceIdentifier(&raw_session)) || raw_session == nullptr) {
        CoTaskMemFree(raw_session);
        continue;
      }
      const std::wstring instance_id(raw_session);
      CoTaskMemFree(raw_session);
      const std::wstring key = device_id + L"\n" +
          (IsEqualGUID(grouping, GUID_NULL) ? L"s:" + instance_id
                                            : L"g:" + GuidString(grouping));
      float level = 0;
      BOOL muted = FALSE;
      if (FAILED(volume->GetMasterVolume(&level)) || FAILED(volume->GetMute(&muted)) ||
          !std::isfinite(level)) continue;
      auto& group = groups[key];
      const bool is_active = state == AudioSessionStateActive;
      if (group.sessions.empty() || (is_active && !group.has_active)) {
        group.state.name = ToUtf8(SessionName(control.Get()));
        group.state.device = device_name;
        group.state.level = static_cast<int32_t>(
            std::lround(std::clamp(level, 0.0f, 1.0f) * 100.0f));
        group.state.muted = muted != FALSE;
        group.state.system_sounds = control->IsSystemSoundsSession() == S_OK;
        group.has_active = is_active;
      }
      group.sessions.push_back({control, volume, grouping});
    }
  }
  if (device_count > 0 && available_devices == 0) return last_error;

  std::map<std::wstring, std::string> next_ids;
  std::map<std::string, std::vector<LiveSession>> next_live;
  std::vector<MixerSession> next_sessions;
  for (auto& [key, group] : groups) {
    const auto old = impl_->ids.find(key);
    const std::string id = old == impl_->ids.end()
        ? std::to_string(impl_->next_id++) : old->second;
    next_ids.emplace(key, id);
    group.state.id = id;
    next_live.emplace(id, std::move(group.sessions));
    next_sessions.push_back(std::move(group.state));
  }
  std::sort(next_sessions.begin(), next_sessions.end(), [](const auto& a, const auto& b) {
    if (a.name != b.name) return a.name < b.name;
    if (a.device != b.device) return a.device < b.device;
    return a.id < b.id;
  });
  impl_->ids = std::move(next_ids);
  impl_->live = std::move(next_live);
  *sessions = std::move(next_sessions);
  return S_OK;
}

HRESULT AudioMixer::SetLevel(const std::string& id, int32_t level) {
  if (level < 0 || level > 100) return E_INVALIDARG;
  return impl_->Set(id, [level](ISimpleAudioVolume* volume) {
    return volume->SetMasterVolume(level / 100.0f, nullptr);
  });
}

HRESULT AudioMixer::SetMute(const std::string& id, bool muted) {
  return impl_->Set(id, [muted](ISimpleAudioVolume* volume) {
    return volume->SetMute(muted ? TRUE : FALSE, nullptr);
  });
}
