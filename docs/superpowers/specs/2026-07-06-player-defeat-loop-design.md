# Player Defeat Loop Design

## Goal

Complete the core run loop for the vertical slice: the player can lose health, see remaining health, and end the run when health reaches zero.

## Scope

- HUD displays player health as `HP current/max`.
- `GameLoop` connects the player's `HealthComponent` signals during `_ready`.
- Damage updates the HUD immediately.
- Player death sets `run_ended`, calculates settlement rewards from the existing run summary, and pauses the game tree when available.
- Boss victory keeps using the existing `record_enemy_defeat` path.

## Rules

- Player defeat does not mark `boss_defeated`.
- Settlement rewards on defeat still include collected `base_materials` and defeated enemy count.
- Repeated death signals must not recalculate or duplicate settlement state after the run has ended.

## Testing

- HUD unit coverage verifies health label formatting.
- Game loop summary coverage verifies player defeat ends the run and calculates non-boss settlement rewards.
- Full Godot headless tests and scene smoke test must pass before committing.
