# Upgrade Effect Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compact effect previews to run upgrade choices and settlement equipment upgrade offers.

**Architecture:** Summaries are derived from existing upgrade and equipment dictionaries, then passed through the existing UI data flow. UI scripts only render text when the summary field is present.

**Tech Stack:** Godot 4.7, GDScript, existing JSON data, existing custom test runner.

---

### Task 1: Runtime Upgrade Summaries

**Files:**
- Modify: `tests/test_upgrade_system.gd`
- Modify: `scripts/systems/upgrade_system.gd`
- Modify: `tests/run_all_tests.gd`
- Create: `tests/test_upgrade_choice_panel.gd`
- Modify: `scripts/ui/upgrade_choice_panel.gd`

- [x] Write a failing test that expects `UpgradeSystem.get_choices()` to include `effect_summary` for stat, weapon level, and weapon unlock upgrade dictionaries.
- [x] Run `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd` and verify the new assertion fails because `effect_summary` is missing.
- [x] Add a small formatter inside `UpgradeSystem` that duplicates choice dictionaries and attaches short summaries from existing fields.
- [x] Write a failing UI test that expects `UpgradeChoicePanel.show_choices()` to render `Name - Summary`.
- [x] Register the new UI test in `tests/run_all_tests.gd`.
- [x] Update `UpgradeChoicePanel` button text formatting and rerun the full test suite.

### Task 2: Settlement Equipment Summaries

**Files:**
- Modify: `tests/test_game_loop_summary.gd`
- Modify: `tests/test_settlement_panel.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `scripts/ui/settlement_panel.gd`

- [x] Write failing assertions that settlement offers include summaries such as `HP +10`, `Speed +18`, `CD -5%`, and `Pickup +24, Mat +10%`.
- [x] Write failing assertions that settlement labels render `Name Lv.N - Summary`.
- [x] Add a formatter in `GameLoop` that derives `stat_summary` from equipment `stat_modifiers`.
- [x] Update `SettlementPanel` label formatting to append `stat_summary` when present.
- [x] Rerun the full test suite and the 5 second headless scene smoke test.

### Task 3: Visual Smoke And Publish

**Files:**
- No source files beyond Tasks 1-2.

- [x] Launch the project in a fresh Godot debug window and capture the portrait view.
- [x] Confirm the upgrade overlay displays effect summaries without obvious overlap.
- [x] Review `git diff`.
- [ ] Commit with `feat: show upgrade effect previews`.
- [ ] Push `main` to GitHub.
