# Settlement Equipment Upgrade UI Design

## Problem

The project now has saved materials, equipment levels that affect runs, and an equipment upgrade transaction. The missing mobile-facing link is a tappable place to spend materials after a run.

## Scope

- Add one settlement-panel upgrade entry for `talisman_robe`.
- Show total saved materials after settlement rewards are persisted.
- Show current Talisman Robe level and next upgrade cost.
- Emit an upgrade request when the player taps the upgrade button.
- GameLoop handles the request, saves the upgraded equipment level, and refreshes the offer.

## Approach

`SettlementPanel` stays presentational. It exposes `show_upgrade_offer(...)` and emits `upgrade_requested(equipment_id)`.

`GameLoop` owns save mutation. After settlement rewards are persisted, it loads save data, asks `EquipmentSystem` for the robe cost and upgrade availability, and updates the panel. When the panel emits an upgrade request, GameLoop performs `EquipmentSystem.upgrade_equipment_in_save`, saves the result, and refreshes the panel.

## Out Of Scope

- Full equipment menu.
- Multiple equipment choices.
- Icons or image assets for the upgrade entry.
