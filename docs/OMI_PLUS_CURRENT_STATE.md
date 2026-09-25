# Omi+ Current State

Date: 2026-09-24

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
- Voice output in standalone mode bypasses Omi cloud TTS and uses the phone/local fallback path.
- Google Drive is the user-owned cloud boundary through Grizzy. The Drive tree is Omi+/Conversations, Audio, Memories, Tasks, Attachments, Backups and Exports.
- Assistant exchanges and attachments use the bounded Drive bridge. Tasks persist locally and mirror to Omi+/Tasks; standalone task mutations never call the Omi API.
- Public Drive writes use the already-exposed authenticated /omi/assistant endpoint in storage mode; Google credentials remain only on the NucBox.
- Phone-call provider no longer performs Omi verified-number cloud preload in standalone mode.
- Stock regression gate: 13/13 targeted tests PASS.
- Standalone replacement gate: 8/8 targeted tests PASS.
- Grizzy branch feature/omi-plus-assistant is at 0f750a9 with 78/78 tests PASS and npm run check PASS.
- Public subscription assistant routing and public Google Drive task writes both return HTTP 200.
- Android standalone dev APK compile: PASS.
- Pixel proof completed before the USB cable fault: stock Omi and Omi+ dev coexist, and Omi+ retained files/models/ggml-tiny.bin (74 MB).

## Existing related work preserved
- /data/repos/omi-chatgpt: non-destructive Omi -> ChatGPT MCP bridge.
- /data/repos/omi-chatgpt-app-check: previous wearable app experiment; intentionally left untouched because it has unrelated local release/Firebase changes.
- /data/repos/omi-le-audio: experimental LE Audio firmware; remains separate and non-default.

## Next vertical slice
Replace Omi conversation processing and memories with local-first stores plus subscription-generated structure, mirrored to Google Drive. Reuse the existing Omi Conversations/Memories UI instead of creating parallel screens. After the Pixel USB link is stable again, reinstall the current standalone APK and physically validate pendant -> local Whisper -> Grizzy -> local TTS.

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
