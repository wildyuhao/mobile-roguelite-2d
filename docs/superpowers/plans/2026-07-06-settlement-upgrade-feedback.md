# Settlement Upgrade Feedback Plan

1. Add tests for a hidden-by-default settlement upgrade feedback label and for `show_upgrade_feedback`.
2. Add a GameLoop test proving an emitted settlement upgrade request produces a success feedback message with the upgraded display name and new level.
3. Add `UpgradeFeedbackLabel` to `SettlementPanel.tscn`.
4. Implement `SettlementPanel.show_upgrade_feedback` and reset it in `show_result`.
5. Call the feedback method from `GameLoop.upgrade_settlement_equipment` after a successful save and offer refresh.
6. Run full tests, headless scene smoke, and a visual settlement feedback smoke check.
