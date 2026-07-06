# Settlement Upgrade Feedback Design

## Problem

Settlement equipment upgrades currently spend materials and refresh levels, but the player does not get an immediate confirmation that the tap succeeded. On mobile this can feel like the button ignored the input, especially when the refreshed row still looks visually similar.

## Design

- Show one compact success line under the total materials label after a successful equipment upgrade.
- Text format: `Upgraded <Display Name> Lv.<Level>`.
- Hide and clear the success line whenever a new settlement result is shown.
- Keep the feedback in the existing settlement panel instead of adding a modal, so repeated upgrades stay fast.
- Trigger the feedback only after `equipment_system.upgrade_equipment_in_save` returns success and the save/offer refresh has completed.

## Verification

- Unit test the settlement panel node, visibility, message text, and reset behavior.
- Unit test that `GameLoop` forwards the upgraded equipment display name and new level after a successful settlement upgrade.
- Run full Godot tests plus a headless scene smoke test.
