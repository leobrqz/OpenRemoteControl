#ifndef RUNNER_AUDIO_VOLUME_H_
#define RUNNER_AUDIO_VOLUME_H_

#include <windows.h>

#include <cstdint>

struct OutputVolume {
  int32_t level;
  bool muted;
};

// COM must be initialized on the calling thread. ERROR_NOT_FOUND indicates that
// there is currently no default output device.
HRESULT ReadDefaultOutputVolume(OutputVolume* state);

#endif  // RUNNER_AUDIO_VOLUME_H_
