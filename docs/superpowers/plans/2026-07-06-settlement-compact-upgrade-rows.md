# Settlement Compact Upgrade Rows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make settlement equipment upgrade choices consume one row each on portrait mobile screens.

**Architecture:** The scene owns row layout through `HBoxContainer` nodes. `SettlementPanel.gd` resolves labels and buttons from the new row paths while preserving the legacy single-offer controls.

**Tech Stack:** Godot 4.7, GDScript, existing custom test runner.

---

### Task 1: Settlement Row Layout Tests

**Files:**
- Modify: `tests/test_settlement_panel.gd`

- [x] Add assertions that `UpgradeRow1` through `UpgradeRow4` exist under `PanelContainer/VBoxContainer`.
- [x] Update multi-offer assertions to read labels and buttons from each row path.
- [x] Assert each row upgrade button has a minimum width of at least `112` pixels.
- [x] Run `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd` and verify the new row assertions fail.

### Task 2: Scene And Script Layout

**Files:**
- Modify: `scenes/ui/SettlementPanel.tscn`
- Modify: `scripts/ui/settlement_panel.gd`

- [x] Add four `HBoxContainer` offer rows to `SettlementPanel.tscn`.
- [x] Move `UpgradeLabel1..4` and `UpgradeButton1..4` under those row containers.
- [x] Set label horizontal expand/fill flags and button stable minimum size.
- [x] Update `SettlementPanel.gd` onready paths and fallback node resolution paths.
- [x] Run the full test suite and verify it passes.

### Task 3: Visual Smoke And Publish

**Files:**
- Temporary visual smoke script, deleted before commit.

- [x] Run the 5 second headless scene smoke test.
- [x] Create and run a temporary settlement-panel visual smoke script.
- [x] Capture the portrait settlement panel and confirm four compact rows fit without obvious overlap.
- [x] Delete the temporary smoke script.
- [x] Review `git diff`.
- [ ] Commit with `feat: compact settlement upgrade rows`.
- [ ] Push `main` to GitHub.
