# Settlement Route Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compact colored route tags to settlement equipment upgrade rows.

**Architecture:** `GameLoop` adds route metadata to settlement offers. `SettlementPanel.tscn` owns route label nodes, and `SettlementPanel.gd` renders offer metadata into those labels.

**Tech Stack:** Godot 4.7, GDScript, existing custom test runner.

---

### Task 1: Route Metadata Tests

**Files:**
- Modify: `tests/test_game_loop_summary.gd`
- Modify: `tests/test_settlement_panel.gd`

- [x] Add assertions that the four settlement offers include route labels `HP`, `SPD`, `CD`, and `LOOT`.
- [x] Add assertions that `UpgradeRouteLabel1..4` exist in `SettlementPanel`.
- [x] Add assertions that route labels render the supplied route text and keep a minimum width of at least `48` pixels.
- [x] Run the full test suite and verify the new assertions fail.

### Task 2: Route Metadata And UI

**Files:**
- Modify: `scripts/core/game_loop.gd`
- Modify: `scenes/ui/SettlementPanel.tscn`
- Modify: `scripts/ui/settlement_panel.gd`

- [x] Add route label/color helpers in `GameLoop`.
- [x] Add route label nodes to each settlement upgrade row.
- [x] Resolve route label nodes in `SettlementPanel.gd`.
- [x] Render route text and route color for visible offers.
- [x] Run the full test suite and verify it passes.

### Task 3: Visual Smoke And Publish

**Files:**
- Temporary visual smoke script, deleted before commit.

- [x] Run the 5 second headless scene smoke test.
- [x] Run a temporary settlement-panel visual smoke script with route tags.
- [x] Capture the portrait settlement panel and confirm tags are readable without overlap.
- [x] Delete the temporary smoke script.
- [x] Review `git diff`.
- [ ] Commit with `feat: add settlement route tags`.
- [ ] Push `main` to GitHub.
