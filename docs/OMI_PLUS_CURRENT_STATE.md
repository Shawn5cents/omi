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
- Additive Omi+ settings persist in SharedPreferences and survive sign-out as device behavior.
- Provider targets defined: Omi, Auto, ChatGPT, Claude, Gemini, Local, All.
- Defaults fail closed to stock Omi and Omi+ disabled.
- Device Settings exposes Omi+ only for Omi hardware; Local assistant is intentionally not selectable yet.
- Explicit device-button voice requests can use Omi+ router -> Grizzy -> subscription client -> Omi voice playback.
- Omi+ command STT can now be switched to the existing on-device Whisper engine; this applies only to explicit Omi+ button requests.
- Local STT is strict opt-in: if a downloaded Whisper model is unavailable or local transcription fails, Omi+ does not silently fall back to Omi cloud STT.
- Ambient Omi capture, summaries, memories, tasks, apps, sync and normal chat remain on stock Omi paths.
- Grizzy read-only assistant branch: feature/omi-plus-assistant at 02e6e45.
- Grizzy verification: 74/74 tests PASS and npm run check PASS.
- Live subscription routing proven for Codex, Claude and Antigravity; public omi.nicholsai.com Auto routing also proven.
- Mobile targeted gate: prior 24/24 PASS; new local-STT/provider gate 9/9 PASS and Device Settings/local-STT gate 9/9 PASS.
- Static analysis of Omi+ STT, message provider and Device Settings: PASS with no issues.
- Android dev APK compile with the private Omi+ assistant route and local-STT slice: PASS.

## Existing related work preserved
- /data/repos/omi-chatgpt: non-destructive Omi -> ChatGPT MCP bridge.
- /data/repos/omi-chatgpt-app-check: previous wearable app experiment; intentionally left untouched because it has unrelated local release/Firebase changes.
- /data/repos/omi-le-audio: experimental LE Audio firmware; remains separate and non-default.

## Next vertical slice
Physically validate the private APK with the Omi pendant and downloaded Whisper model on Android. Then benchmark Omi's existing Whisper path against LiteRT/Edge candidates such as Parakeet and Qwen3-ASR behind the same Omi+ STT interface; only replace Whisper if measured latency, accuracy and battery results justify it.

## Release gate
Do not merge into main until:
1. stock Android build passes,
2. Omi+ settings tests pass,
3. provider defaults remain stock Omi,
4. disabling Omi+ restores stock behavior,
5. no unrelated upstream files are modified.
