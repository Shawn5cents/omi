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
- Device Settings exposes Omi+ only for Omi hardware; Local is intentionally not selectable yet.
- Explicit device-button voice requests can use Omi STT -> Omi+ router -> Grizzy -> subscription client -> Omi voice playback.
- Ambient Omi capture, summaries, memories, tasks, apps, sync and normal chat remain on stock Omi paths.
- Grizzy read-only assistant branch: feature/omi-plus-assistant at d59346f.
- Grizzy verification: 74/74 tests PASS and npm run check PASS.
- Mobile targeted gate: 24/24 tests PASS.
- Static analysis of the new assistant API, message provider and Device Settings: PASS.
- Android dev APK compile: PASS after standard Omi setup/codegen.

## Existing related work preserved
- /data/repos/omi-chatgpt: non-destructive Omi -> ChatGPT MCP bridge.
- /data/repos/omi-chatgpt-app-check: previous wearable app experiment; intentionally left untouched because it has unrelated local release/Firebase changes.
- /data/repos/omi-le-audio: experimental LE Audio firmware; remains separate and non-default.

## Next vertical slice
Deploy the authenticated Grizzy assistant route, validate one real subscription-backed end-to-end request, then replace Omi cloud transcription with the first on-device STT candidate behind the same routing contract.

## Release gate
Do not merge into main until:
1. stock Android build passes,
2. Omi+ settings tests pass,
3. provider defaults remain stock Omi,
4. disabling Omi+ restores stock behavior,
5. no unrelated upstream files are modified.
