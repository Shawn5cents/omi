# Omi+ Current State

Date: 2026-09-25

## Canonical workspace
- Worktree: /data/repos/omi-plus
- Branch: feature/omi-plus
- Base: BasedHardware/omi upstream main at 7293efca4a51018c955bca23726f09f8ebc62e0e

## Completed
- Clean Omi+ worktree created from current upstream.
- Full roadmap documented.
- Architecture and ownership boundaries documented.
- Stock Omi remains available as the production package; the private dev flavor is the Omi+ standalone build.
- Provider targets remain defined: Omi, Auto, ChatGPT, Claude, Gemini, Local, All. Stock mode keeps stock defaults; standalone mode forces Omi+ ON, Auto subscription routing and local STT.
- Standalone startup bypasses Omi/Firebase identity, FCM, Crashlytics, Intercom, subscription/paywall bootstrap and Omi cloud account initialization.
- Explicit pendant-button requests and normal typed chat route through Grizzy subscription clients instead of Omi AI.
- Live subscription routing is proven for Codex/ChatGPT, Claude Code and Antigravity/Gemini.
- Omi+ standalone transcription uses the downloaded on-device Whisper model and never silently falls back to Omi cloud STT.
- Standalone capture resolution blocks Omi managed transcription sockets and forces local on-device STT.
- Voice output in standalone mode bypasses Omi cloud TTS. Omi+ now prefers the separate HayaiTTS Android engine with the verified local Piper Amy voice and automatically falls back to the untouched Android system TTS engine if Hayai is unavailable or rejects synthesis.
- Google Drive is the user-owned cloud boundary through Grizzy. The Drive tree is Omi+/Conversations, Audio, Memories, Tasks, Attachments, Backups and Exports.
- Assistant exchanges and attachments use the bounded Drive bridge. Tasks persist locally and mirror to Omi+/Tasks; standalone task mutations never call the Omi API.
- Public Drive writes use the bounded Grizzy storage path; Google credentials remain only on the NucBox.
- Supabase Collective now provides the durable request ledger and pgmq retry queue. Requests survive phone/network/NucBox interruptions instead of depending on a live tunnel.
- The phone and worker use the Supabase `omi-ingress` Edge Function as the public gateway; direct anonymous/signed-in execution of the underlying SECURITY DEFINER RPCs has been revoked.
- Supabase Edge is already Cloudflare-fronted, so the durable path does not depend on the `omi.nicholsai.com` tunnel. A dedicated Cloudflare Worker is not required for reliability at this stage.
- `omi-health` reports worker heartbeat, queue depth, processing age and failures without depending on the NucBox HTTP endpoint. Live health is green with worker online, zero queued/processing jobs and zero failures.
- Grizzy's durable worker is a persistent systemd user service with restart-on-failure, bounded local model-call timeout and periodic heartbeat.
- The app maintains a local idempotent outbox and checks unfinished jobs on startup and every 30 seconds; completed assistant answers are restored into chat after reconnect/restart.
- Phone-call provider no longer performs Omi verified-number cloud preload in standalone mode.
- Standalone transport has defense-in-depth HTTP and WebSocket blocks against Omi cloud endpoints.
- Command Whisper remains warm between button requests and prefers the configured/device language instead of language auto-detection when possible.
- Standalone local-STT gate: 4/4 PASS. Stock/command STT regression gate: 14/14 PASS. Durable Edge client gate: 2/2 PASS. Grizzy worker reliability gate: 2/2 PASS; `npm run check` PASS.
- Supabase security advisor no longer reports Omi-specific public SECURITY DEFINER warnings after gateway lockdown.
- Android static analysis of the hardened slice: 0 errors. Standalone dev APK compile: PASS.
- HayaiTTS v2.5.1 is installed separately on the Pixel as an Android TTS engine; Omi+ discovers it via the standard TTS service query and does not embed/link its GPL runtime.
- Verified voice: `vits-piper-en_US-amy-low` (~67 MB). The smaller `vits-piper-en_US-amy-low-int8` catalog entry is broken in HayaiTTS v2.5.1 (`Bundle missing required files: model.onnx`) and must not be selected.
- Pixel hardware TTS integration test: PASS; HayaiTTS is discoverable and Piper Amy synthesizes offline. Android system TTS remains the fallback.
- Latest Pixel standalone install: PASS; pendant auto-reconnects; local Whisper starts; launch trace has no Firebase, Omi WebSocket or composite Omi fallback.

## Existing related work preserved
- /data/repos/omi-chatgpt: non-destructive Omi -> ChatGPT MCP bridge.
- /data/repos/omi-chatgpt-app-check: previous wearable app experiment; intentionally left untouched because it has unrelated local release/Firebase changes.
- /data/repos/omi-le-audio: experimental LE Audio firmware; remains separate and non-default.

## Next vertical slice
Complete the remaining local-first conversation/memory projection and physically benchmark pendant button -> warm local Whisper -> durable Supabase queue -> subscription model -> local TTS. The current tiny Whisper path is functional but measured slower than real time on one sample, so benchmark Base/other on-device candidates only after the reliable end-to-end command path is locked.

## Release gate
Do not merge the standalone work into a distributable release until:
1. stock Android mode still passes its regression gate,
2. standalone mode boots without Firebase/Omi cloud identity,
3. no ambient or command audio is silently sent to Omi cloud,
4. ChatGPT/Claude/Gemini subscription routes pass live tests,
5. conversations, memories, tasks and attachments have local persistence plus Google Drive recovery,
6. the Pixel + pendant hardware path passes end to end,
7. the prototype embedded credential is replaced by revocable device enrollment before wider distribution,
8. no unrelated upstream files are modified.
