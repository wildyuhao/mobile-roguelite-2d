# Equipment Run Stats Design

## Problem

Materials can now persist after settlement, and save data already contains `equipment_levels`, but equipment levels do not affect the next run. This makes meta progression feel unfinished on mobile because rewards are stored without visible power.

## Scope

- Equipped unlocked items apply their stat modifiers when a run starts.
- Missing equipment levels count as level 1, so starter gear remains useful.
- Saved levels above 1 scale numeric stat modifiers linearly.
- Player max health and move speed consume the applied modifiers in the first pass.

## Approach

`EquipmentSystem` will accept an optional `equipment_levels` dictionary and multiply each equipped item's stat modifiers by its saved level. `GameLoop` will load save data during `_ready`, equip `unlocked_equipment`, compute total modifiers, and pass them to `PlayerController`.

`PlayerController` will expose `apply_stat_modifiers` for max health and move speed. The method keeps the base values as exported defaults, so repeated calls remain predictable in tests and future menu previews.

## Out Of Scope

- Equipment upgrade spending UI.
- Main menu equipment screen.
- Non-player modifiers such as material gain, pickup radius, or weapon cooldown.
