# Settlement Material Bonus Display Design

## Problem

`Jade Compass` now increases settlement material rewards, but the result panel only shows the final material total. Players cannot tell that the equipment made a difference.

## Scope

- Add one optional `Material Bonus +X` line to the settlement panel.
- Show the line only when `settlement_rewards.material_bonus` is greater than zero.
- Keep existing total material text unchanged so older flows and tests remain simple.

## Approach

`SettlementPanel.tscn` will add a `MaterialBonusLabel` near the material reward line. `settlement_panel.gd` will resolve that node and update visibility/text in `show_result()`.

## Testing

- Settlement panel test verifies the bonus label exists.
- It stays hidden for rewards without `material_bonus`.
- It becomes visible and shows `Material Bonus +10` when rewards include a positive bonus.

## Out Of Scope

- New icons or art.
- Rebalancing material gain.
- Detailed per-equipment breakdown.
