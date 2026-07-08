# Runtime Upgrade Feedback Design

## Problem

Runtime upgrade choices now have mobile-sized buttons, but after the player taps one, the panel immediately disappears and combat resumes. On a phone this can leave the player unsure whether the intended choice was selected.

## Design

- Add a lightweight HUD feedback line for runtime upgrade selections.
- Text format: `<Upgrade Name> selected`.
- Show the message after `GameLoop` applies the chosen upgrade and before combat resumes.
- Hide the message automatically after a short duration so it does not compete with combat information.
- Keep the feedback in `HUD` instead of adding another modal or pausing layer.

## Verification

- Unit test that HUD exposes the feedback label, shows the selected upgrade, and hides it after its timer expires.
- Unit test that `GameLoop` forwards the selected upgrade display name to HUD when an upgrade is selected.
- Run full Godot tests, headless scene smoke, and a rendered visual smoke image.
