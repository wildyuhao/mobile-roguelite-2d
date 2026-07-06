# Settlement Multi Equipment Upgrades Design

## Problem

The settlement screen can spend materials on Talisman Robe, but a single fixed upgrade makes the meta loop feel narrow. Mobile players should have a few clear upgrade choices after each run without opening a separate menu yet.

## Scope

- Show up to three unlocked equipment upgrade offers on the settlement panel.
- Prioritize stat-bearing equipment so upgrades visibly affect future runs.
- Each offer shows display name, level, cost, and affordability.
- Tapping any offer emits its equipment id and GameLoop performs the same save-backed upgrade transaction.
- After an upgrade, all offers refresh from the latest save data.

## Approach

`SettlementPanel` will gain `show_upgrade_offers(offers)` while keeping the existing single-offer method as a compatibility wrapper. The scene will contain three fixed mobile-sized upgrade buttons with matching labels.

`GameLoop` will build offers from unlocked equipment definitions, limited to three ids. It will reuse `EquipmentSystem.get_upgrade_cost`, `can_upgrade`, and `upgrade_equipment_in_save`.

## Out Of Scope

- Full equipment inventory.
- Scrollable upgrade list.
- New icons or art assets.
