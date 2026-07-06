# Upgrade Effect Preview Design

## Goal

Make mobile upgrade decisions readable at a glance by showing short effect previews on run upgrades and settlement equipment upgrades.

## Context

The current vertical mobile UI shows upgrade names such as `Spirit Magnet`, `Quick Invocation`, and `Attune Demon-Sealing Bell`. These names have flavor, but they do not explain the gameplay effect. On a phone-sized screen this slows decisions and makes early runs feel arbitrary.

## Design

- Add a compact `effect_summary` field to run upgrade choices.
- Add a compact `stat_summary` field to settlement equipment offers.
- Format summaries from existing data instead of adding parallel balance text to JSON.
- Keep wording short enough for portrait buttons and labels:
  - `Damage +15%`
  - `CD -8%`
  - `Pickup +24`
  - `Speed +24`
  - `HP +12`
  - `Unlock Weapon`
  - `Weapon Lv +1`
  - `Pickup +24, Mat +10%`

## UI Behavior

Run upgrade buttons should show `Name - Summary` when a summary exists, and fall back to the current name-only text otherwise.

Settlement equipment labels should show `Name Lv.N - Summary` when a summary exists, and fall back to the current `Name Lv.N` text otherwise.

## Testing

- `UpgradeSystem` should add effect summaries to generated choices.
- `UpgradeChoicePanel` should render summaries in button text.
- `GameLoop` settlement offers should include stat summaries derived from equipment modifiers.
- `SettlementPanel` should render settlement summaries in label text.
