// SPDX-License-Identifier: MPL-2.0
// Public C interface consumed by the Lazarus AudioBackendPulse binding.
#ifndef MORSE_RUNNER_AUDIO_BACKEND_PULSE_H
#define MORSE_RUNNER_AUDIO_BACKEND_PULSE_H

int AudioBackendPulse_Start(int sampleRate, int bufFrames, int numBufs);
void AudioBackendPulse_Stop(void);
int AudioBackendPulse_Write(const float *samples, int nFrames);
int AudioBackendPulse_NeedsData(void);
void AudioBackendPulse_ClearNeedsData(void);
int AudioBackendPulse_TakeNeedsData(void);
int AudioBackendPulse_Available(void);
int AudioBackendPulse_IsRunning(void);
int AudioBackendPulse_LastError(void);
void AudioBackendPulse_SetVolume(float vol);

#endif
