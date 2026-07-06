# Settlement Compact Upgrade Rows Design

## Goal

Reduce settlement panel vertical crowding on mobile while keeping all four equipment upgrade routes visible and easy to tap.

## Context

The settlement panel now shows four equipment upgrade choices with useful stat summaries. Each choice currently consumes two vertical controls: a label and an upgrade button. On a portrait mobile layout this makes the settlement panel feel tall and forces the reward summary, material total, upgrade options, and restart button to compete for space.

## Design

- Keep the existing reward and material text unchanged.
- Keep the legacy single-offer label and button for compatibility, but hide them in multi-offer mode as today.
- Put each multi-offer equipment choice inside one `HBoxContainer` row.
- Each row contains:
  - a left label with `Name Lv.N - Summary`;
  - a right upgrade button with the material cost.
- Give upgrade buttons a stable minimum width so the tap target does not shrink when costs change.

## Testing

- `SettlementPanel` should expose four `UpgradeRow` containers.
- Each row should contain the matching label and button.
- Buttons should keep a stable minimum touch width.
- Existing upgrade request behavior should continue to emit the correct equipment id.
