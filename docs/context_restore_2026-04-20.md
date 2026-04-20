# Context Restore - 2026-04-20

## Source

- Restored from `F:\AIGC\rollout-2026-04-09T16-01-43-019d7142-e9fc-7792-a78e-98e80014eb6b.txt`
- The `.txt` file is still line-delimited session JSON, so it can be treated as the old `jsonl` rollout log.
- The log spans roughly `2026-04-09` to `2026-04-20`.

## Project Snapshot

- Project: `Cuoti-DouDui`
- Goal: a mobile app that captures wrong-answer questions, calls AI for analysis, and supports review planning.
- Current stack:
  - `frontend`: Flutter app
  - `backend`: FastAPI service
  - `ai_engine`: LLM/OCR/animation generation logic
- The early repo started as frontend-heavy mock data plus mostly empty backend/AI skeletons, then the backend AI path was progressively built out.

## Main Architecture That Was Built

- `POST /api/v1/analysis/image`
  - Uses OCR plus multimodal analysis.
  - No longer stays on the old pure "OCR text -> text model" path.
- `POST /api/v1/analysis/physics-animation`
  - Separated from main image analysis.
  - Used for on-demand physics animation / HTML artifact generation.
- Structured analysis response now includes:
  - `scene_brief`
  - `rich_artifacts`
  - `interactive_html` artifacts for WebView rendering
- Frontend was wired to consume backend data instead of only local mock flows.

## Important Features Added During The Old Session

- Vivo-compatible backend client and FastAPI MVP skeleton were added.
- Frontend got a minimal real backend connection path.
- LaTeX rendering support was added on the Flutter side.
- `interactive_html` artifacts can be previewed in WebView.
- Subject-specific expansion logic was added, especially for physics.
- Physics animation flow evolved into:
  - full HTML generation when possible
  - lighter scene-spec renderers for some physics branches
  - explicit handling for `circuit` and `electromagnetism`
- `scene_brief` was added and propagated through backend and frontend.
- Image upload compatibility was hardened:
  - MIME type normalization based on image bytes
  - fallback handling for `invalid base64_image_url`
  - extra logging around upload filename/content type/image size

## What The Current Repo Still Matches

These markers are present in the current workspace and confirm the restored context still lines up with the repo:

- `backend/app/schemas/card_schema.py`
  - has `scene_brief` and `rich_artifacts`
- `ai_engine/llm_logic/diagnostic_chain.py`
  - contains physics HTML generation logic
  - contains `scene_brief` handling
  - contains logs for:
    - `physics animation used full html generation`
    - `physics animation used circuit scene spec renderer`
    - `physics animation used electromagnetism scene spec renderer`
- `ai_engine/llm_logic/vivo_client.py`
  - contains image MIME normalization
- `backend/app/api/v1/upload.py`
  - contains fallback markers including `invalid base64_image_url`
- `frontend/lib/screen/capture/error_edit_screen.dart`
  - contains `interactive_html` display handling

Current repo HEAD when restored: `dffb75f`

## Recurring Problems From The Old Session

- Animation quality vs latency was the core tradeoff.
- Full HTML generation produced better scene fidelity, but often hit:
  - long latency
  - upstream `504 Gateway Time-out`
  - truncated or empty HTML when token budget was reduced
- Some physics/electromagnetism questions were misrouted into generic template paths before scene-specific logic was added.
- App-side uploads and `/docs` manual tests sometimes behaved differently because uploaded image metadata and MIME handling differed.
- Cloud deployment introduced a second debugging layer:
  - server `.env` drift
  - `systemd`-managed backend restarts
  - Tencent Cloud security group / port exposure issues

## Latest Restored State Before Provider Trouble

- Work had progressed to debugging cloud behavior with `Doubao-Seed-2.0-pro` as the vision model.
- A backend compatibility fix was added so app uploads are normalized before vision requests.
- The most recent successful context indicates:
  - app-triggered image analysis could fail even when backend direct tests succeeded
  - the likely cause was image upload metadata / Data URI strictness
  - backend-side mitigation was implemented without requiring Flutter changes

## Last Unfinished Conversation Thread

The final unanswered user question in the old log was about model `reasoning_effort`:

- the user noticed provider docs mentioning `minimal`, `low`, `medium`, `high`
- they wanted to know which mode the current project code was using
- the provider started returning repeated `429` and `503`, so that question never received a real answer in the old session

## Safe Continuation Notes

- This restored note is a working memory summary, not a byte-for-byte restoration of hidden model state.
- If we continue from here, the best immediate next step is to answer the unfinished `reasoning_effort` question from the current code/config and then continue debugging the active model path if needed.
- The old rollout log contains a plaintext API secret from a prior `.env` read. Do not reuse that log as a shareable artifact. Rotate any key that was exposed there.
