# Contact Damage Design

## Goal

Make the vertical slice playable as a survival action loop: enemies that reach the player should deal contact damage, while the player gets a short invulnerability window so one overlap does not drain all health instantly.

## Scope

- Enemy contact damage is driven by each enemy definition's `contact_damage`.
- Player health is still owned by the existing `HealthComponent`.
- The player exposes a small damage API with an invulnerability timer.
- Enemy agents check distance to the player and call the player damage API when close enough.
- Player death can be detected by the game loop later for settlement/game-over UI; this step focuses on taking damage safely.

## Rules

- Contact damage applies at most once per player invulnerability window.
- The default invulnerability window is `0.6` seconds.
- Enemy contact range defaults to its configured collision radius plus the player's collision radius.
- If a scene is missing collision shapes, code falls back to conservative defaults.

## Testing

- Unit tests cover player damage and invulnerability.
- Enemy agent tests cover contact damage through `contact_damage`.
- Full Godot test suite and headless scene smoke test must pass before committing.
