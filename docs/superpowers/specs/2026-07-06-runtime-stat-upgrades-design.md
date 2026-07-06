# Runtime Stat Upgrades Design

## Problem

Level-up choices already include stat upgrades such as damage, cooldown, pickup radius, move speed, and max health. Only weapon unlocks and weapon levels currently change the run. On mobile this makes some choices feel broken, especially `Spirit Magnet`, because precise pickup movement is harder on touch controls.

## Scope

- Convert selected `kind: "stat"` upgrades into summed runtime modifiers.
- Reuse the same modifier pipeline that equipment already uses for player and weapon stats.
- Apply pickup radius to spawned experience pickups by enlarging their collection area.
- Keep settlement and meta-equipment behavior unchanged in this pass.

## Approach

`UpgradeSystem` will expose `get_stat_modifiers(runtime_state)`, summing `value * stacks` for each selected stat upgrade.

`GameLoop` will combine saved equipment modifiers and runtime upgrade modifiers into one active modifier dictionary. It will send that dictionary to the player and weapon system, and store it for pickup spawning.

`ExperiencePickup` will expose `set_collection_radius_bonus(bonus)`, which expands its collection circle from its base radius. Runtime `pickup_radius` will use that method when pickups are spawned.

## Testing

- Upgrade system test: stacked `pickup_radius_1` produces `pickup_radius = 48`.
- Weapon system test: `weapon_damage_multiplier = 0.25` raises Flying Sword damage from 12 to 15.
- Pickup test: a pickup collection circle grows from 10 to 34 with a +24 bonus, then restores.
- Game loop test: runtime stat upgrades are merged and passed to player, weapon system, and spawned pickups.

## Out Of Scope

- Material gain settlement economy.
- New UI copy for showing stat deltas.
- New art assets.
