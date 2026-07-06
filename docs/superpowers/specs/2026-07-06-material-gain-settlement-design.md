# Material Gain Settlement Design

## Problem

`Jade Compass` defines `material_gain`, but settlement rewards ignore it. That makes the equipment look useful in data while providing no economic benefit after a run.

## Scope

- Settlement rewards accept a `material_gain` value from the run summary.
- The bonus applies to the final material total after enemy drops and boss bonus.
- `GameLoop` passes the active modifier value into both boss victory and player defeat settlement calculations.
- Saved materials persist the boosted total exactly once, using the existing save path.

## Approach

`SettlementSystem.calculate_rewards()` will compute the existing base material total, then add `round(base_total * material_gain)` as a non-negative bonus. The returned dictionary will include `material_bonus` so UI can expose it later without recalculating.

`GameLoop` will prepare a settlement summary by copying `run_summary` and adding `material_gain` from `active_stat_modifiers`. Both win and defeat paths will use this helper before persisting rewards.

## Testing

- Settlement system: 39 base materials with `material_gain = 0.25` returns 49 total and 10 bonus.
- Game loop: saved level 2 `Jade Compass` gives `material_gain = 0.2`, turning a 69-material boss result into 83 saved materials.

## Out Of Scope

- New result-panel text for showing the bonus line.
- Unlocking new equipment in the save.
- Balancing material costs.
