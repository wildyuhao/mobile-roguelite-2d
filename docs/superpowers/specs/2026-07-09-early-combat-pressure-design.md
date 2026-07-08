# Early Combat Pressure Design

## Problem

The first run currently spawns four enemies at time 0, then waits until 60 seconds for the next wave. Once the first enemies are defeated and the player collects the first experience pickups, the level-up flow can resume into an empty field. With no enemies alive, automatic weapons have no targets, so the game feels like only pickups exist.

## Design

- Keep the existing enemy art and weapon art; referenced production assets already exist.
- Increase early wave cadence so the first minute keeps pressure on the player.
- Require early waves to occur at least every 12 seconds from 0 to 60 seconds.
- Set the main scene spawn radius to 360 pixels so early enemies appear near the mobile viewport edge and inside the starting flying sword range.
- Keep spawn counts modest and ramp gradually so the mobile screen remains readable.
- Preserve later enemy variety: basic demons first, then charging demons, ranged demons, elite guardian, and boss.

## Verification

- Add a data test that rejects first-minute wave gaps larger than 12 seconds.
- Add a data test that requires multiple first-minute waves.
- Add a scene composition test that keeps the main spawn radius mobile-visible.
- Run full Godot tests and a headless scene smoke test.
