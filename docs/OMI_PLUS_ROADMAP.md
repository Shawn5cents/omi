# Omi+ Roadmap

## Product rule
Keep Omi's hardware, BLE, capture, firmware and local app UX. Stock Omi remains installable separately. The private Omi+ standalone build replaces Omi-hosted AI/cloud dependencies with local processing, Grizzy subscription lanes and user-owned Google Drive storage.

## Target
Omi pendant + Omi app UX + local speech + Grizzy + subscription-backed ChatGPT/Claude/Gemini + Google Drive, while preserving device controls, recording/capture behavior, firmware support and familiar Omi conversation/memory/task surfaces.

## Delivery order
### Phase 0 - Preserve and baseline
- Track BasedHardware/omi as upstream.
- Maintain a clean Omi+ worktree and branch.
- Record upstream commit for every release.
- Build stock Android app before feature changes.
- Add parity checklist for stock Omi surfaces.

### Phase 1 - Assistant routing
- Add Omi+ settings model.
- Add provider choices: Omi, Auto, ChatGPT, Claude, Gemini, Local, Ask All.
- Default remains Omi.
- Route only explicit wearable assistant requests; ambient capture remains stock Omi.
- Grizzy is the orchestration boundary.

### Phase 2 - Local STT
- Add speech engine interface.
- Reuse and baseline Omi's existing on-device Whisper engine first.
- Local mode is strict: never fall back to cloud STT without the user turning local mode off.
- Benchmark Parakeet and Qwen3-ASR candidates through LiteRT behind the same interface.
- Measure word error rate, command latency, battery and thermals on Pixel before changing the default local engine.

### Phase 3 - Local TTS
- Use Android's standard TTS interface so voice engines remain replaceable.
- Preferred standalone engine: HayaiTTS with local Piper Amy; keep Android system TTS as automatic fallback.
- Keep HayaiTTS as a separate Android engine rather than embedding its native GPL runtime into Omi+.
- The verified Piper voice is `vits-piper-en_US-amy-low`; avoid HayaiTTS v2.5.1's broken Amy INT8 catalog entry.
- Benchmark higher-quality Hayai/sherpa-onnx voices such as Kokoro or Kitten only after the Piper path is stable.
- Stream answers to Bluetooth earbuds.
- Never route pendant as an output device.

### Phase 4 - Grizzy subscription lanes
- ChatGPT via supported subscription-backed OpenAI client path.
- Claude via Claude Code subscription lane.
- Gemini via supported Google account client.
- No credential extraction or private API impersonation.
- Add health, timeout, quota and fallback status.

### Phase 5 - Local second brain + Google Drive
- Replace Omi conversation processing with local transcript persistence plus subscription-generated structure.
- Reuse the existing Conversations UI against the local store.
- Replace Omi memory CRUD with a local memory ledger and Google Drive mirror.
- Keep tasks local-first and mirrored to Omi+/Tasks.
- Store conversations, memories, audio, attachments, backups and exports under the fixed Omi+ Drive tree.
- Query Grizzy/Collective for projects, repos, machines and tools only when explicitly requested.

### Phase 6 - Live translation
- Omi audio -> local STT -> translation -> local TTS -> earbud.
- Push-to-start initially; continuous mode only after latency/battery proof.
- Add language pair and privacy controls.

### Phase 7 - Actions
- Voice commands through Grizzy for repos, Collective, home devices and connected services.
- Require confirmations for destructive/high-impact actions.
- Keep action receipts.

### Phase 8 - Upstream maintenance and release
- Rebase/merge upstream regularly.
- Run parity, Android build and Omi+ tests before every merge.
- Ship internal APK first.
- Firmware changes remain optional and separate.

## Definition of done for v0.1
1. Stock Omi remains installable and its production package is untouched.
2. Standalone Omi+ boots without Omi/Firebase account or subscription dependencies.
3. Pendant and typed requests route to Grizzy subscription clients.
4. Ambient and command transcription can run locally with no silent Omi-cloud fallback.
5. Conversations, memories, tasks and attachments are local-first and mirrored to Google Drive.
6. Omi cloud TTS is replaced by local/phone TTS in standalone mode.
7. No OpenAI/Anthropic/Google model API key is required for subscription lanes.
8. Pixel + pendant end-to-end validation passes.
9. Repository is clean and upstream lineage is documented.

## Deferred until evidence justifies them
- Replacing Omi firmware.
- Native Android LE Audio microphone routing.
- Always-on live translation.
- Rewriting Omi's UI instead of reusing it.
- Introducing a new paid cloud database when Google Drive + local state are sufficient.
