# Zerror Flat UI Figma Handoff

This folder contains the local Figma handoff for the flat UI redesign.

## Files

- `zerror-flat-ui-board.png`: one-board visual reference with foundations, assets, and representative screens.
- `figma-sync-manifest.json`: source of truth for Figma file key, style tokens, generated assets, and representative screens.
- `design-tokens.json`: machine-readable colors, radii, spacing, typography, and effects.
- `figma-build-flat-redesign.js`: paste into `use_figma` after the Figma MCP call limit is lifted to create editable frames.
- `verify-handoff.js`: local Node verifier for this handoff package.

## Target Figma File

- Name: `Zerror Flat UI Redesign`
- File key: `FBfQTUkBHS7TnI0dOvIiIV`
- URL: `https://www.figma.com/design/FBfQTUkBHS7TnI0dOvIiIV`

## Recovery Steps

1. Confirm the Figma MCP Starter plan limit is no longer blocking tool calls.
2. Run `node frontend/design_exports/verify-handoff.js` from the repo root.
3. Use `design-tokens.json` as the source when creating Figma variables/styles.
4. Use `upload_assets` to place `zerror-flat-ui-board.png` into the target design file as the visual reference.
5. Run `figma-build-flat-redesign.js` with `use_figma` against the same file key.
6. Upload these image assets and place them into the matching placeholders:
   - `frontend/assets/images/flat_study_illustration.png`
   - `frontend/assets/images/ai_chat_illustration.png`
   - `frontend/assets/images/empty_study_illustration.png`
   - `frontend/assets/images/flat_chat_icon.png`
7. Compare the editable frames with the Flutter source screens listed in `figma-sync-manifest.json`.

## Constraints

- Do not run `flutter`, `dart`, `flutter analyze`, `flutter run`, or `flutter build` in this Codex environment.
- Keep preview/canvas interiors functionally dark where the app needs contrast; unify the outer shell, controls, and panels.
- Keep generated raster assets in `frontend/assets/images` and registered in `frontend/pubspec.yaml`.
