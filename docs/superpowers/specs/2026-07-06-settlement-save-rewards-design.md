# Settlement Save Rewards Design

## Problem

The run can now calculate rewards and show a settlement panel, but earned materials do not persist after the run ends. On mobile this weakens the core loop because a short run has no lasting reward.

## Scope

- When a boss is defeated, settlement rewards are added to saved materials once.
- When the player is defeated, settlement rewards are also added to saved materials once.
- Repeated defeat or late enemy signals after `run_ended` must not duplicate saved rewards.
- The settlement panel continues to receive the same reward and summary dictionaries.

## Approach

`GameLoop` owns the moment a run ends, so it should persist settlement rewards immediately after `SettlementSystem.calculate_rewards`. It will use the existing `SaveSystem`, load the current save, add `settlement_rewards.materials`, and write the updated save back.

Tests will inject a fake save system into `GameLoop` and verify both victory and defeat paths save the expected total once.

## Out Of Scope

- Equipment upgrade spending.
- Main menu material display.
- Cloud saves or Android export configuration.
