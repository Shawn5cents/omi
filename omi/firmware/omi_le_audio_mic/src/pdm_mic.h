#pragma once

#include <stddef.h>
#include <stdint.h>

#define OMI_LE_AUDIO_SAMPLE_RATE_HZ 16000
#define OMI_LE_AUDIO_FRAME_SAMPLES 160

int omi_pdm_mic_start(void);
int omi_pdm_mic_get_frame(int16_t *out, size_t samples);
