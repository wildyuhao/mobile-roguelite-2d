# Runtime Upgrade Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Confirm runtime upgrade selections with a short HUD message after combat resumes.

**Architecture:** Extend the existing `HUD` scene with one hidden label and timer logic. Have `GameLoop._on_upgrade_selected` call a HUD method with the selected upgrade display name.

**Tech Stack:** Godot 4.7, GDScript, existing lightweight test runner.

## Global Constraints

- Keep the existing three-choice upgrade flow.
- Do not add a new modal, pause layer, or asset dependency.
- Feedback text format is `<Upgrade Name> selected`.

---

### Task 1: HUD Feedback Behavior

**Files:**
- Modify: `scenes/ui/HUD.tscn`
- Modify: `scripts/ui/hud.gd`
- Modify: `tests/test_hud.gd`

**Interfaces:**
- Produces: `HUD.show_upgrade_feedback(display_name: String) -> void`

- [ ] **Step 1: Write the failing HUD test**

Assert that `UpgradeFeedbackLabel` exists, starts hidden, `show_upgrade_feedback("Sharpened Edge")` shows `Sharpened Edge selected`, and `_process` hides the label after the feedback duration.

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd`

Expected: FAIL because the HUD has no feedback node or method yet.

- [ ] **Step 3: Implement HUD label and timer**

Add `UpgradeFeedbackLabel`, `UPGRADE_FEEDBACK_DURATION`, and `show_upgrade_feedback`.

### Task 2: GameLoop Hook

**Files:**
- Modify: `scripts/core/game_loop.gd`
- Modify: `tests/test_game_loop_summary.gd`

**Interfaces:**
- Consumes: `HUD.show_upgrade_feedback(display_name: String) -> void`

- [ ] **Step 1: Write the failing GameLoop test**

Create a fake HUD with `show_upgrade_feedback`, call the runtime upgrade feedback helper with an upgrade dictionary, and assert the HUD receives `Sharpened Edge`.

- [ ] **Step 2: Run test to verify it fails**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd`

Expected: FAIL because `GameLoop` does not call HUD feedback yet.

- [ ] **Step 3: Implement the GameLoop call**

After applying the selected upgrade and stat modifiers, call HUD feedback with `display_name` or fallback `id`.

### Task 3: Verification And Commit

**Files:**
- Verify: all modified files

- [ ] **Step 1: Run full tests**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd`

Expected: `All tests passed.`

- [ ] **Step 2: Run scene smoke**

Run: `Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 5`

Expected: exit code 0.

- [ ] **Step 3: Run visual smoke**

Render a temporary HUD feedback screenshot and inspect the generated image.

- [ ] **Step 4: Commit and push**

Commit message: `feat: show runtime upgrade feedback`.
