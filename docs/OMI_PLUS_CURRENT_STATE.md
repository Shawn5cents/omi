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
- Initial additive settings model implemented.
- Provider targets defined: Omi, Auto, ChatGPT, Claude, Gemini, Local, All.
- Defaults fail closed to stock Omi and Omi+ disabled.
- Unit tests: 3/3 PASS.

## Existing related work preserved
- /data/repos/omi-chatgpt: non-destructive Omi -> ChatGPT MCP bridge.
- /data/repos/omi-chatgpt-app-check: previous wearable app experiment; intentionally left untouched because it has unrelated local release/Firebase changes.
- /data/repos/omi-le-audio: experimental LE Audio firmware; remains separate and non-default.

## Next vertical slice
Persist Omi+ settings in SharedPreferences, expose them in Device Settings, and route one explicit wearable request to a Grizzy adapter while leaving stock Omi ambient capture unchanged.

## Release gate
Do not merge into main until:
1. stock Android build passes,
2. Omi+ settings tests pass,
3. provider defaults remain stock Omi,
4. disabling Omi+ restores stock behavior,
5. no unrelated upstream files are modified.
