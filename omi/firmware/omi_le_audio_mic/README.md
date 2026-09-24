# Omi LE Audio Microphone Experiment

Experimental firmware for using an Omi pendant as a standards-compliant Bluetooth LE Audio microphone.

This is the firmware implementation for the standalone `Shawn5cents/omi-chatgpt` project.

## Goal

```text
Omi T5838 microphones
  -> nRF5340 PDM
  -> 16 kHz mono PCM
  -> LC3
  -> BAP source ASE / CIS
  -> Android LE Audio input
  -> stock ChatGPT app
```

There is no OpenAI API integration in this firmware.

## Current implementation

- source-only BAP Unicast Server
- zero sink ASEs
- one source ASE
- LE Audio peripheral
- 16 kHz / mono
- 10 ms LC3 frames
- T5838 dual-PDM capture mixed to mono
- explicit PDM_EN rail power-up and THSEL low
- ISO SDUs sent with `bt_bap_stream_send()`
- source contexts: Conversational + Media
- Bluetooth name: `Omi ChatGPT Mic`

The source-only profile is deliberate. Omi has no speaker; the first Android test should avoid advertising an audio sink that could steal ChatGPT playback from the phone or earbuds.

## Dual-core build

The experiment uses Omi's normal nRF53 boot/update structure:

- MCUboot
- b0n
- nRF5340 application core
- IPC radio network core
- network core with Connected Isochronous Peripheral support
- two-image DFU package

Verified network-core Kconfig:

```text
CONFIG_BT_ISO_PERIPHERAL=y
CONFIG_BT_CTLR_PERIPHERAL_ISO=y
CONFIG_BT_CTLR_CONN_ISO=y
CONFIG_BT_CTLR_CONN_ISO_STREAMS=1
```

## Build

Requires nRF Connect SDK 2.9.0.

On the Nichols NucBox the verified build is:

```sh
export LD_LIBRARY_PATH=/data/ncs/toolchains/b77d8c1312/usr/local/lib:${LD_LIBRARY_PATH:-}
export PATH=/data/ncs/toolchains/b77d8c1312/usr/local/bin:/data/ncs/toolchains/b77d8c1312/bin:$PATH

cd /data/ncs/v2.9.0
west build \
  -b omi/nrf5340/cpuapp \
  /data/repos/omi-le-audio/omi/firmware/omi_le_audio_mic \
  --sysbuild \
  -d /data/build-omi-le-audio-ota \
  -- \
  -DBOARD_ROOT=/data/repos/omi-le-audio/omi/firmware
```

Output:

```text
/data/build-omi-le-audio-ota/dfu_application.zip
```

Verified artifact SHA-256:

```text
018e40db3b807eba66ff29335fac53595fb5921fed3369b31a21810da0e38947
```

The DFU zip contains:

- `omi_le_audio_mic.signed.bin`
- `ipc_radio.bin`
- `manifest.json`

## Build evidence

Application core after microphone power fix:

- Flash: 258,028 B / 982,528 B
- RAM: 70,160 B / 440 KB

Network core:

- Flash: 197,888 B / 222 KB
- RAM: 41,836 B / 64 KB

## Hardware test gate

This branch is not ready to merge into normal Omi firmware until a real pendant/Android test proves:

1. OTA installs and reboots normally.
2. Android pairs `Omi ChatGPT Mic`.
3. Android exposes it as LE Audio microphone/input.
4. an ordinary Android recorder captures the Omi microphone.
5. stock ChatGPT dictation captures the Omi microphone.
6. ChatGPT Voice captures Omi while output remains usable through the phone or separate earbuds.
7. reconnect and screen-lock behavior are stable.

If Android requires a bidirectional headset profile for communication routing, add a sink ASE only after the source-only test fails.
