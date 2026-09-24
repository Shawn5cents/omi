# Omi+ Architecture

## Principle
Do not fork Omi into a different product. Extend it through narrow interfaces and keep upstream mergeable.

## Data paths

### Stock Omi path
Omi pendant -> Omi BLE/audio -> stock capture/transcription -> conversations, memories, summaries, tasks and apps.

### Omi+ assistant path
Explicit button/command -> transcript -> Omi+ Router -> Grizzy -> selected provider -> text response -> optional local TTS -> earbuds.

### Local speech path
Omi audio -> local VAD/STT -> transcript. Raw audio stays local when local mode is selected.

## Boundaries
- Omi owns pendant connectivity and stock second-brain behavior.
- Omi+ Router owns user-selected assistant routing.
- Grizzy owns orchestration and machine/tool actions.
- Speech engines implement STT/TTS behind replaceable interfaces.
- Provider adapters call supported clients; they do not scrape credentials.

## Provider modes
- omi: unchanged stock behavior.
- auto: Grizzy chooses an available configured lane.
- chatgpt: OpenAI subscription-backed client lane.
- claude: Claude subscription-backed client lane.
- gemini: Google subscription-backed client lane.
- local: on-device or NucBox model.
- all: fan out intentionally and present labeled responses.

## Safety and privacy defaults
- Omi is the default provider until the user changes it.
- Ambient transcripts are never automatically sent to external assistants.
- Omi+ assistant invocation is explicit.
- Destructive Grizzy actions require confirmation.
- Raw audio upload is independently controllable.
- Provider health and data destination are visible in settings.

## Repository strategy
origin: Shawn5cents/omi
upstream: BasedHardware/omi
canonical development worktree: /data/repos/omi-plus
branch: feature/omi-plus

Firmware LE Audio work stays separate from application Omi+ until Android routing is proven necessary.
