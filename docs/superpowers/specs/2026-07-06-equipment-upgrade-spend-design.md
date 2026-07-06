# Equipment Upgrade Spend Design

## Problem

Runs now save materials and equipment levels affect the next run, but there is still no rule that spends materials to raise equipment levels. This leaves the meta loop incomplete: earn materials, but cannot convert them into power.

## Scope

- Add a deterministic equipment upgrade transaction that mutates save data.
- Upgrade cost is `10 * current_level`; missing levels count as level 1.
- A successful upgrade subtracts materials and increments the equipment level by 1.
- An upgrade fails without changing save data if the item is locked, unknown, or materials are insufficient.

## Approach

`EquipmentSystem` already owns equipment definitions and level scaling, so it will expose:

- `get_upgrade_cost(equipment_id, save_data)`
- `can_upgrade(equipment_id, save_data)`
- `upgrade_equipment_in_save(equipment_id, save_data)`

The method returns a compact result dictionary for future UI wiring. This keeps the first pass testable without adding a menu screen yet.

## Out Of Scope

- Equipment upgrade UI.
- Max-level caps.
- Multiple currencies or rarity-specific costs.
