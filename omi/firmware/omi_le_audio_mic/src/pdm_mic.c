#include "pdm_mic.h"

#include <errno.h>
#include <string.h>

#include <zephyr/audio/dmic.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(omi_pdm_mic, LOG_LEVEL_INF);

#define INPUT_CHANNELS 2
#define BYTES_PER_SAMPLE sizeof(int16_t)
#define BLOCK_SIZE (OMI_LE_AUDIO_FRAME_SAMPLES * INPUT_CHANNELS * BYTES_PER_SAMPLE)
#define BLOCK_COUNT 6

struct pcm_frame {
	int16_t samples[OMI_LE_AUDIO_FRAME_SAMPLES];
};

K_MEM_SLAB_DEFINE_STATIC(mic_slab, BLOCK_SIZE, BLOCK_COUNT, 4);
K_MSGQ_DEFINE(pcm_q, sizeof(struct pcm_frame), 12, 4);

static const struct device *dmic_dev;

static void mic_thread(void *a, void *b, void *c)
{
	ARG_UNUSED(a);
	ARG_UNUSED(b);
	ARG_UNUSED(c);

	while (true) {
		void *buffer = NULL;
		uint32_t size = 0;
		int ret = dmic_read(dmic_dev, 0, &buffer, &size, 1000);

		if (ret < 0) {
			LOG_WRN("dmic_read failed: %d", ret);
			continue;
		}

		if (size < BLOCK_SIZE) {
			LOG_WRN("short PDM block: %u", size);
			k_mem_slab_free(&mic_slab, buffer);
			continue;
		}

		const int16_t *stereo = buffer;
		struct pcm_frame frame;

		for (size_t i = 0; i < OMI_LE_AUDIO_FRAME_SAMPLES; ++i) {
			int32_t mixed = (int32_t)stereo[i * 2] + (int32_t)stereo[i * 2 + 1];
			frame.samples[i] = (int16_t)(mixed / 2);
		}

		if (k_msgq_put(&pcm_q, &frame, K_NO_WAIT) != 0) {
			struct pcm_frame dropped;
			(void)k_msgq_get(&pcm_q, &dropped, K_NO_WAIT);
			(void)k_msgq_put(&pcm_q, &frame, K_NO_WAIT);
		}

		k_mem_slab_free(&mic_slab, buffer);
	}
}

K_THREAD_DEFINE(omi_pdm_thread, 2048, mic_thread, NULL, NULL, NULL, 5, 0, -1);

int omi_pdm_mic_start(void)
{
	dmic_dev = DEVICE_DT_GET(DT_ALIAS(dmic0));
	if (!device_is_ready(dmic_dev)) {
		LOG_ERR("DMIC device not ready");
		return -ENODEV;
	}

	struct pcm_stream_cfg stream = {
		.pcm_width = 16,
		.mem_slab = &mic_slab,
		.pcm_rate = OMI_LE_AUDIO_SAMPLE_RATE_HZ,
		.block_size = BLOCK_SIZE,
	};

	struct dmic_cfg cfg = {
		.io = {
			.min_pdm_clk_freq = 512000,
			.max_pdm_clk_freq = 3500000,
			.min_pdm_clk_dc = 48,
			.max_pdm_clk_dc = 52,
		},
		.streams = &stream,
		.channel = {
			.req_num_streams = 1,
			.req_num_chan = INPUT_CHANNELS,
			.req_chan_map_lo =
				dmic_build_channel_map(0, 0, PDM_CHAN_LEFT) |
				dmic_build_channel_map(1, 0, PDM_CHAN_RIGHT),
		},
	};

	int ret = dmic_configure(dmic_dev, &cfg);
	if (ret < 0) {
		LOG_ERR("dmic_configure failed: %d", ret);
		return ret;
	}

	ret = dmic_trigger(dmic_dev, DMIC_TRIGGER_START);
	if (ret < 0) {
		LOG_ERR("dmic start failed: %d", ret);
		return ret;
	}

	k_thread_start(omi_pdm_thread);
	LOG_INF("Omi PDM mic started at 16 kHz mono output");
	return 0;
}

int omi_pdm_mic_get_frame(int16_t *out, size_t samples)
{
	if (out == NULL || samples != OMI_LE_AUDIO_FRAME_SAMPLES) {
		return -EINVAL;
	}

	struct pcm_frame frame;
	if (k_msgq_get(&pcm_q, &frame, K_NO_WAIT) != 0) {
		memset(out, 0, samples * sizeof(int16_t));
		return -EAGAIN;
	}

	memcpy(out, frame.samples, sizeof(frame.samples));
	return 0;
}
