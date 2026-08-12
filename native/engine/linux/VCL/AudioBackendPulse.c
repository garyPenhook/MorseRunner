// AudioBackendPulse.c — Streaming PulseAudio backend for Morse Runner Linux port.
// Called from Pascal (FPC / Lazarus). Drop-in replacement for AudioBackend2.m
// (CoreAudio macOS backend) with identical C function signatures.
//
// Architecture (same as macOS):
//   Pascal main thread  → AudioBackendPulse_Write() → lock-free ring buffer
//   Playback thread     → pulse_thread_func()       → reads from ring buffer
//
// When the ring buffer falls below the low-water mark, gNeedsData is set to 1.
// A TTimer in SndOut.pas polls this flag from the main thread, fires
// OnBufAvailable, and the application calls PutData() /
// AudioBackendPulse_Write() to refill the ring buffer.
//
// Key difference from the naive "write silence on underrun" approach:
//   When the ring buffer is empty the playback thread WAITS (2 ms sleep) instead
//   of injecting silence into the PulseAudio stream.  Injecting silence fills
//   PulseAudio's internal buffer ahead of real audio, causing audible gaps.
//   GetAudio() in Contest.pas always produces real samples (including intended
//   zero-valued silence), so the ring is only truly empty at startup or on a
//   very long delay — both cases where a brief wait is correct.
//
// Thread safety: single-producer (Pascal main thread) / single-consumer
// (playback thread) lock-free ring buffer. The producer publishes samples with
// a release store of gWritePos; the consumer observes them with an acquire
// load. The consumer releases a slot with gReadPos and the producer acquires it.
//
// Build:
//   gcc -c AudioBackendPulse.c -o AudioBackendPulse.o -fPIC
//       $(pkg-config --cflags libpulse-simple) -O2

#include <pulse/simple.h>
#include <pulse/error.h>
#include "AudioBackendPulse.h"
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdatomic.h>
#include <string.h>
#include <time.h>

// ---------------------------------------------------------------------------
// Ring buffer — size must be a power of 2 for the modulo-by-AND trick.
// At 11025 Hz mono float32, 65536 frames ≈ 5.9 seconds of audio.
// ---------------------------------------------------------------------------
#define RING_FRAMES 65536U
#define RING_MASK   (RING_FRAMES - 1U)
#define MAX_CHUNK_FRAMES 512U

enum {
    AUDIO_BACKEND_PULSE_ERR_ALREADY_RUNNING = -1,
    AUDIO_BACKEND_PULSE_ERR_THREAD_CREATE = -2,
    AUDIO_BACKEND_PULSE_ERR_INVALID_ARGUMENT = -3
};

static float gRing[RING_FRAMES];
static _Atomic uint32_t gReadPos = 0U;   // written only by playback thread
static _Atomic uint32_t gWritePos = 0U;  // written only by Pascal main thread
static _Atomic int gNeedsData = 0;       // set by playback thread, taken by Pascal

static pa_simple *gPulse = NULL;
static pthread_t gThread;
static int gThreadStarted = 0;
static uint32_t gBufFrames = MAX_CHUNK_FRAMES;
static uint32_t gLowWater = 2048U;
static _Atomic int gRunning = 0;
static _Atomic int gLastError = 0;
static _Atomic float gVolume = 1.0f;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Frames currently available in the ring buffer for reading.
static uint32_t RingAvailable(void)
{
    uint32_t w = atomic_load_explicit(&gWritePos, memory_order_acquire);
    uint32_t r = atomic_load_explicit(&gReadPos, memory_order_acquire);
    return (w - r) & RING_MASK;
}

// Free slots in the ring buffer (Pascal may write this many frames).
static uint32_t RingSpace(void)
{
    return RING_MASK - RingAvailable();
}

static void sleep_ms(int ms)
{
    struct timespec ts;
    ts.tv_sec  = ms / 1000;
    ts.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&ts, NULL);
}

// ---------------------------------------------------------------------------
// Playback thread — reads from ring buffer and writes to PulseAudio.
// Runs until gRunning is cleared.
//
// Design: wait for a full chunk before writing. Never write silence when the
// ring is empty — that injects dead frames ahead of real audio in PA's buffer.
// ---------------------------------------------------------------------------
static void *pulse_thread_func(void *arg)
{
    (void)arg;
    float buf[MAX_CHUNK_FRAMES];
    int error;
    uint32_t nFrames = gBufFrames;

    while (atomic_load_explicit(&gRunning, memory_order_acquire) != 0) {

        /* Wait until the ring contains at least one full chunk.
           Sleep 2 ms between checks — well under one buffer period (~46 ms). */
        while ((atomic_load_explicit(&gRunning, memory_order_acquire) != 0) &&
               (RingAvailable() < nFrames)) {
            atomic_store_explicit(&gNeedsData, 1, memory_order_release);
            sleep_ms(2);
        }
        if (atomic_load_explicit(&gRunning, memory_order_acquire) == 0) {
            break;
        }

        /* Copy nFrames from ring buffer, apply volume. */
        uint32_t rp = atomic_load_explicit(&gReadPos, memory_order_relaxed);
        float volume = atomic_load_explicit(&gVolume, memory_order_relaxed);
        uint32_t i;
        for (i = 0U; i < nFrames; ++i) {
            buf[i] = gRing[rp & RING_MASK] * volume;
            ++rp;
        }
        atomic_store_explicit(&gReadPos, rp & RING_MASK, memory_order_release);

        /* Write to PulseAudio — blocking call paces the thread to the
           hardware clock (~46 ms per 512-frame chunk at 11025 Hz). */
        if (pa_simple_write(gPulse, buf, (size_t)nFrames * sizeof(float), &error) < 0) {
            fprintf(stderr, "AudioBackendPulse: pa_simple_write failed: %s\n",
                    pa_strerror(error));
            if (atomic_load_explicit(&gRunning, memory_order_acquire) != 0) {
                atomic_store_explicit(&gLastError, error, memory_order_release);
                atomic_store_explicit(&gRunning, 0, memory_order_release);
                atomic_store_explicit(&gNeedsData, 1, memory_order_release);
            }
            break;
        }

        /* Signal the Pascal main thread to refill if below low-water mark. */
        if (RingAvailable() < gLowWater)
            atomic_store_explicit(&gNeedsData, 1, memory_order_release);
    }

    return NULL;
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_Start
//   sampleRate  - Hz (typically 11025 for Morse Runner)
//   bufFrames   - frames per write chunk (typically 512)
//   numBufs     - number of logical buffers (sets low-water mark)
// Returns 0 on success, non-zero on failure.
// ---------------------------------------------------------------------------
int AudioBackendPulse_Start(int sampleRate, int bufFrames, int numBufs)
{
    size_t targetBytes;
    int error;

    if (atomic_load_explicit(&gRunning, memory_order_acquire) != 0) {
        return AUDIO_BACKEND_PULSE_ERR_ALREADY_RUNNING;
    }

    if ((sampleRate <= 0) || ((uint32_t)sampleRate > PA_RATE_MAX) ||
        (bufFrames <= 0) || ((uint32_t)bufFrames > MAX_CHUNK_FRAMES) ||
        (numBufs <= 0) ||
        ((uint32_t)numBufs > (RING_MASK / (uint32_t)bufFrames))) {
        atomic_store_explicit(&gLastError,
                              AUDIO_BACKEND_PULSE_ERR_INVALID_ARGUMENT,
                              memory_order_release);
        return AUDIO_BACKEND_PULSE_ERR_INVALID_ARGUMENT;
    }

    targetBytes = (size_t)(uint32_t)bufFrames * (size_t)(uint32_t)numBufs *
                  sizeof(float);
    if (targetBytes > UINT32_MAX) {
        atomic_store_explicit(&gLastError,
                              AUDIO_BACKEND_PULSE_ERR_INVALID_ARGUMENT,
                              memory_order_release);
        return AUDIO_BACKEND_PULSE_ERR_INVALID_ARGUMENT;
    }

    gBufFrames = (uint32_t)bufFrames;
    gLowWater = (uint32_t)bufFrames * (uint32_t)numBufs;
    atomic_store_explicit(&gReadPos, 0U, memory_order_relaxed);
    atomic_store_explicit(&gWritePos, 0U, memory_order_relaxed);
    atomic_store_explicit(&gLastError, 0, memory_order_release);
    atomic_store_explicit(&gNeedsData, 1, memory_order_release);

    memset(gRing, 0, sizeof(gRing));

    // PulseAudio sample format: mono float32
    pa_sample_spec ss;
    ss.format   = PA_SAMPLE_FLOAT32LE;
    ss.rate     = (uint32_t)sampleRate;
    ss.channels = 1;

    // Let PulseAudio choose its own buffer sizes (maxlength = -1 means default).
    // We do our own buffering in the ring; PA just needs enough to hide OS jitter.
    pa_buffer_attr ba;
    memset(&ba, 0, sizeof(ba));
    ba.maxlength = (uint32_t)-1;
    ba.tlength   = (uint32_t)targetBytes;
    ba.prebuf    = (uint32_t)bufFrames * (uint32_t)sizeof(float);
    ba.minreq    = (uint32_t)bufFrames * (uint32_t)sizeof(float);
    ba.fragsize  = (uint32_t)-1;  // not used for playback

    gPulse = pa_simple_new(
        NULL,               // default server
        "MorseRunner",      // application name
        PA_STREAM_PLAYBACK,
        NULL,               // default device
        "Contest Audio",    // stream description
        &ss,
        NULL,               // default channel map
        &ba,
        &error
    );

    if (!gPulse) {
        fprintf(stderr, "AudioBackendPulse: pa_simple_new failed: %s\n",
                pa_strerror(error));
        atomic_store_explicit(&gLastError, error, memory_order_release);
        return error;
    }

    atomic_store_explicit(&gRunning, 1, memory_order_release);

    if (pthread_create(&gThread, NULL, pulse_thread_func, NULL) != 0) {
        fprintf(stderr, "AudioBackendPulse: pthread_create failed\n");
        pa_simple_free(gPulse);
        gPulse = NULL;
        atomic_store_explicit(&gRunning, 0, memory_order_release);
        atomic_store_explicit(&gLastError,
                              AUDIO_BACKEND_PULSE_ERR_THREAD_CREATE,
                              memory_order_release);
        return AUDIO_BACKEND_PULSE_ERR_THREAD_CREATE;
    }
    gThreadStarted = 1;

    return 0;
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_Stop — stop playback and release PulseAudio connection.
// ---------------------------------------------------------------------------
void AudioBackendPulse_Stop(void)
{
    int wasRunning;

    wasRunning = atomic_exchange_explicit(&gRunning, 0, memory_order_acq_rel);
    if (gThreadStarted != 0) {
        pthread_join(gThread, NULL);
        gThreadStarted = 0;
    }

    if (gPulse) {
        int error;
        if ((wasRunning != 0) &&
            (atomic_load_explicit(&gLastError, memory_order_acquire) == 0) &&
            (pa_simple_drain(gPulse, &error) < 0)) {
            atomic_store_explicit(&gLastError, error, memory_order_release);
        }
        pa_simple_free(gPulse);
        gPulse = NULL;
    }
    atomic_store_explicit(&gNeedsData, 0, memory_order_release);
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_Write — called from Pascal main thread to enqueue samples.
//   samples  - float array, values in range [-32767.0 .. +32767.0]
//              (Morse Runner uses unnormalised audio; we normalise to [-1,1])
//   nFrames  - number of samples
// Returns number of frames actually written (may be less if ring is full).
// ---------------------------------------------------------------------------
int AudioBackendPulse_Write(const float *samples, int nFrames)
{
    uint32_t frameCount;
    uint32_t space;
    uint32_t wp;
    uint32_t i;

    if ((samples == NULL) || (nFrames <= 0) ||
        ((uint32_t)nFrames > RING_MASK)) {
        return 0;
    }

    frameCount = (uint32_t)nFrames;
    space = RingSpace();
    if (frameCount > space) {
        return 0;
    }

    wp = atomic_load_explicit(&gWritePos, memory_order_relaxed);
    for (i = 0U; i < frameCount; ++i) {
        // Normalise from [-32767,32767] to [-1,1]
        float v = samples[i] * (1.0f / 32767.0f);
        if (v != v) {
            v = 0.0f;
        }
        if (v >  1.0f) v =  1.0f;
        if (v < -1.0f) v = -1.0f;
        gRing[wp & RING_MASK] = v;
        ++wp;
    }
    atomic_store_explicit(&gWritePos, wp & RING_MASK, memory_order_release);
    return nFrames;
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_NeedsData — returns 1 if the ring buffer needs refilling.
// Called from Pascal's TTimer handler on the main thread.
// ---------------------------------------------------------------------------
int AudioBackendPulse_NeedsData(void)
{
    return atomic_load_explicit(&gNeedsData, memory_order_acquire);
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_ClearNeedsData — clear the refill request flag.
// ---------------------------------------------------------------------------
void AudioBackendPulse_ClearNeedsData(void)
{
    atomic_store_explicit(&gNeedsData, 0, memory_order_release);
}

int AudioBackendPulse_TakeNeedsData(void)
{
    return atomic_exchange_explicit(&gNeedsData, 0, memory_order_acq_rel);
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_Available — frames currently in the ring buffer.
// ---------------------------------------------------------------------------
int AudioBackendPulse_Available(void)
{
    return (int)RingAvailable();
}

int AudioBackendPulse_IsRunning(void)
{
    return atomic_load_explicit(&gRunning, memory_order_acquire);
}

int AudioBackendPulse_LastError(void)
{
    return atomic_load_explicit(&gLastError, memory_order_acquire);
}

// ---------------------------------------------------------------------------
// AudioBackendPulse_SetVolume — set playback volume [0.0 .. 1.0].
// ---------------------------------------------------------------------------
void AudioBackendPulse_SetVolume(float vol)
{
    if (vol != vol) vol = 0.0f;
    if (vol < 0.0f) vol = 0.0f;
    if (vol > 1.0f) vol = 1.0f;
    atomic_store_explicit(&gVolume, vol, memory_order_release);
}
