# Equipment Weapon Cooldown Design

## Problem

The settlement panel now offers `Bronze Gear Core`, but its `weapon_cooldown_multiplier` modifier is not used by combat. Spending materials on it should make weapons fire faster in the next run, otherwise one of the visible meta-upgrades feels cosmetic.

## Scope

- `GameLoop` keeps using `EquipmentSystem.get_total_modifiers()` as the single source of saved equipment stats.
- Player-facing modifiers continue to go to `PlayerController`.
- Weapon-facing modifiers go to `WeaponSystem`.
- `weapon_cooldown_multiplier` is additive in the equipment data and multiplicative against the final weapon cooldown. Example: `-0.1` means 10% faster firing.

## Approach

`WeaponSystem` will expose `set_stat_modifiers(modifiers)`. `get_weapon_cooldown()` will first resolve weapon and level cooldown as it does today, then multiply by `1.0 + weapon_cooldown_multiplier`, clamped so cooldown never drops below the existing safety floor.

`GameLoop.apply_saved_equipment_to_player()` will keep returning all modifiers, but will also pass the same dictionary to `weapon_system.set_stat_modifiers()` when that method exists.

## Testing

- Add a weapon-system test that applies `weapon_cooldown_multiplier = -0.1` and verifies Flying Sword cooldown changes from `0.9` to `0.81`.
- Add a game-loop test that loads saved level 2 `bronze_gear_core` and verifies the weapon system receives `-0.1`.

## Out Of Scope

- New equipment UI.
- Per-weapon-specific equipment effects.
- Runtime equipment swapping during a run.
