#ifndef RUNNER_AUDIO_MIXER_H_
#define RUNNER_AUDIO_MIXER_H_

#include <windows.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

struct MixerSession {
  std::string id;
  std::string name;
  std::string device;
  int32_t level;
  bool muted;
  bool system_sounds;
};

// All methods run on the same COM-initialized platform thread.
class AudioMixer {
 public:
  AudioMixer();
  ~AudioMixer();
  AudioMixer(const AudioMixer&) = delete;
  AudioMixer& operator=(const AudioMixer&) = delete;

  HRESULT Read(std::vector<MixerSession>* sessions);
  // S_FALSE means the session expired or changed grouping before the command.
  HRESULT SetLevel(const std::string& id, int32_t level);
  HRESULT SetMute(const std::string& id, bool muted);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_AUDIO_MIXER_H_
