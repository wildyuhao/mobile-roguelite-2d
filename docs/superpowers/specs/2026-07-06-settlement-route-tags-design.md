# Settlement Route Tags Design

## Goal

Make settlement equipment upgrade routes faster to scan on portrait mobile screens.

## Context

The settlement panel now fits four compact upgrade rows. The rows are readable, but all four labels share the same white text treatment, so the player still has to read each full equipment name and stat summary to understand the decision.

## Design

- Add a compact route tag to each equipment offer row.
- Tags are code-native UI labels, not generated bitmap icons, because the current need is deterministic readability rather than formal art.
- Use short labels that fit in a stable narrow slot:
  - `HP` for Talisman Robe.
  - `SPD` for Cloudstep Boots.
  - `CD` for Bronze Gear Core.
  - `LOOT` for Jade Compass.
- Add a light color tint per tag so the row categories are visually distinct without turning the panel into a loud palette.
- Keep the existing equipment name, stat summary, cost, and upgrade event behavior unchanged.

## Testing

- `GameLoop` settlement offers should include route labels and route colors.
- `SettlementPanel` should expose four route label nodes.
- Route label text and minimum width should be verified in tests.
- Upgrade button events should still emit the correct equipment id.
