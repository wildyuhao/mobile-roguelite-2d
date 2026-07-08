# Upgrade Choice Touch Cards Design

## Problem

Runtime upgrade choices appear during combat level-ups, but the current panel is three default buttons with single-line text. On mobile, this makes each choice feel small, flat, and harder to scan while the player is trying to resume combat quickly.

## Design

- Keep the existing three-choice upgrade flow and pause behavior.
- Add a short panel title and paused-state subtitle so the player understands this is a safe decision moment.
- Give each upgrade button a fixed minimum height of at least 96 pixels to create reliable thumb targets.
- Format choices with an effect summary as two lines:
  - First line: upgrade display name.
  - Second line: effect summary.
- Keep choices without an effect summary as a single display-name line.

## Verification

- Unit test the panel nodes, button touch target height, and two-line choice formatting.
- Run full Godot tests and a headless game scene smoke test.
- Run a visual smoke check to confirm the panel reads correctly in a mobile-sized window.
