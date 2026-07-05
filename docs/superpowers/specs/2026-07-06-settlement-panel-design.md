# Settlement Panel Design

## Goal

Show a clear end-of-run result when the player wins or loses, so the mobile vertical slice has visible closure after combat ends.

## Scope

- Add a `SettlementPanel` CanvasLayer scene.
- The panel is hidden during play and shown when `GameLoop` ends the run.
- It displays result title, materials earned, defeated enemies, and boss status.
- A restart button emits `restart_requested`; `GameLoop` reloads the current scene when running inside a tree.
- Existing reward calculation remains in `SettlementSystem`.

## Rules

- Boss defeat title: `Boss Sealed`.
- Player defeat title: `Run Failed`.
- The panel must use the existing `settlement_rewards` and `run_summary` dictionaries.
- The panel should process while the tree is paused.

## Testing

- Unit tests verify panel text formatting and restart signal.
- Game loop tests verify victory and defeat show the settlement panel.
- Scene composition tests verify the game scene includes the panel.
- Full Godot headless tests and scene smoke test must pass before committing.
