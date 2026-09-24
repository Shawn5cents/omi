# Omi+ Roadmap

## Product rule
Omi+ preserves stock Omi behavior first. Every Omi+ capability is additive, optional, and independently disableable.

## Target
Omi pendant + Omi app + local speech + Grizzy + subscription-backed ChatGPT/Claude/Gemini clients, while retaining Omi conversations, memories, summaries, tasks, apps, device controls, sync, firmware updates, APIs, and MCP.

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
- Baseline stock Omi transcription.
- Add Parakeet and Qwen3-ASR candidates through LiteRT.
- Preserve cloud STT as fallback.
- Measure word error rate, first-token latency, battery and thermals on Pixel.

### Phase 3 - Local TTS
- Add voice output interface.
- Baseline Android system TTS.
- Evaluate KittenTTS Nano and Qwen3-TTS.
- Stream answers to Bluetooth earbuds.
- Never route pendant as an output device.

### Phase 4 - Grizzy subscription lanes
- ChatGPT via supported subscription-backed OpenAI client path.
- Claude via Claude Code subscription lane.
- Gemini via supported Google account client.
- No credential extraction or private API impersonation.
- Add health, timeout, quota and fallback status.

### Phase 5 - Omi memory + Collective context
- Keep Omi conversation/memory store canonical for captured life context.
- Query Grizzy/Collective for projects, repos, machines and tools.
- Add explicit cross-memory query path with source labels.
- Never silently copy all Omi history into Collective.

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
1. Stock Omi Android features still work.
2. Omi+ provider setting defaults to Omi.
3. Explicit wearable request can route to Grizzy and return text.
4. Omi cloud capture path remains available.
5. Omi+ can be disabled without reinstalling.
6. Tests cover provider configuration and routing fallback.
7. No OpenAI/Anthropic/Google API key is required for subscription lanes.
8. Repository is clean and upstream lineage is documented.

## Deferred until evidence justifies them
- Replacing Omi firmware.
- Native Android LE Audio microphone routing.
- Always-on live translation.
- Custom cloud infrastructure duplicating working Omi services.
- Reimplementing Omi memories/tasks/apps.
