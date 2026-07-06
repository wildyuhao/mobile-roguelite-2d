# Default Equipment Pool Design

## Problem

The game now supports health, speed, cooldown, pickup radius, and material gain progression, but a fresh save only unlocks `talisman_robe` and `sword_gourd`. In practice, new players can miss most of the settlement upgrade loop, and older local saves keep the narrow pool.

## Scope

- Fresh saves unlock the baseline settlement equipment pool: `talisman_robe`, `cloudstep_boots`, `bronze_gear_core`, `jade_compass`, plus `sword_gourd`.
- Loaded legacy saves are normalized in memory so they also gain access to the same baseline pool without losing materials, levels, or settings.
- Settlement offers include four upgrade routes: health, speed, cooldown, and economy.
- The settlement panel displays and emits requests for four offers.

## Approach

`SaveSystem` will keep a single `DEFAULT_UNLOCKED_EQUIPMENT` constant and normalize `unlocked_equipment` on `create_default_save()` and `load_game()`.

`GameLoop` will add `jade_compass` to the settlement offer order. `SettlementPanel` will add a fourth label/button pair and reuse the existing array-driven rendering and signal binding.

## Testing

- Save system tests cover default unlocks and legacy save migration.
- Game loop settlement tests expect four offers and verify `jade_compass` can be upgraded.
- Settlement panel tests verify the fourth offer renders and emits `jade_compass`.

## Out Of Scope

- A separate equipment equip/unequip screen.
- Balancing first-run stat bonuses.
- New visual art.
