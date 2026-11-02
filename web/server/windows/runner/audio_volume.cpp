#include "audio_volume.h"

#include <endpointvolume.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>

HRESULT ReadDefaultOutputVolume(OutputVolume* state) {
  if (state == nullptr) return E_POINTER;

  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT status = CoCreateInstance(
      __uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
      IID_PPV_ARGS(enumerator.GetAddressOf()));
  Microsoft::WRL::ComPtr<IMMDevice> device;
  if (SUCCEEDED(status)) {
    status = enumerator->GetDefaultAudioEndpoint(eRender, eConsole,
                                                 device.GetAddressOf());
  }
  Microsoft::WRL::ComPtr<IAudioEndpointVolume> volume;
  if (SUCCEEDED(status)) {
    status = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                              nullptr,
                              reinterpret_cast<void**>(volume.GetAddressOf()));
  }
  float level = 0;
  BOOL muted = FALSE;
  if (SUCCEEDED(status)) status = volume->GetMasterVolumeLevelScalar(&level);
  if (SUCCEEDED(status)) status = volume->GetMute(&muted);
  if (FAILED(status)) return status;
  if (!std::isfinite(level)) return E_FAIL;

  state->level = static_cast<int32_t>(
      std::lround(std::clamp(level, 0.0f, 1.0f) * 100.0f));
  state->muted = muted != FALSE;
  return S_OK;
}
