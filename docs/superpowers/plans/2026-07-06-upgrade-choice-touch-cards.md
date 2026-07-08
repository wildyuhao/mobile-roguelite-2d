# Upgrade Choice Touch Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make runtime upgrade choices easier to tap and scan on mobile.

**Architecture:** Keep `UpgradeChoicePanel` as the single UI surface for level-up choices. Update its scene layout for title/status text and large fixed-height buttons, then adjust formatting in `upgrade_choice_panel.gd`.

**Tech Stack:** Godot 4.7, GDScript, existing lightweight test runner.

---

### Task 1: Failing Panel Test

**Files:**
- Modify: `tests/test_upgrade_choice_panel.gd`

- [ ] **Step 1: Assert touch-card structure**

Add checks that `TitleLabel` and `SubtitleLabel` exist, each choice button has `custom_minimum_size.y >= 96`, and effect summaries render as `Name\nSummary`.

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd`

Expected: FAIL because the panel does not yet have title/subtitle nodes, large buttons, or two-line formatting.

### Task 2: Scene And Script Update

**Files:**
- Modify: `scenes/ui/UpgradeChoicePanel.tscn`
- Modify: `scripts/ui/upgrade_choice_panel.gd`

- [ ] **Step 1: Add title/status labels and large buttons**

Add static title/status labels to the scene and set each button minimum height to at least 96.

- [ ] **Step 2: Format choices as touch cards**

Update `_format_choice_text` so choices with `effect_summary` use a newline separator.

- [ ] **Step 3: Run tests**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd`

Expected: `All tests passed.`

### Task 3: Verification And Commit

**Files:**
- Verify: all modified files

- [ ] **Step 1: Run headless scene smoke**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 5`

Expected: exit code 0.

- [ ] **Step 2: Run visual smoke**

Launch a temporary visual smoke scene showing the upgrade panel and inspect the screenshot for readable title, subtitle, and three large choices.

- [ ] **Step 3: Commit and push**

Commit message: `feat: improve upgrade choice touch targets`
