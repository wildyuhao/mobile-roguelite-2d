# Campaign Shell Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace direct-to-combat startup with a working campaign map -> character selection -> configured battle -> progression settlement -> campaign map loop.

**Architecture:** `AppFlow` owns screen navigation and long-term services. Campaign and character UI consume view data from `ContentCatalog`, `CampaignProgression`, and the version-2 save; `GameLoop` receives a validated run-context dictionary before entering the tree and emits one immutable result. Long-term progression is applied once by `CampaignSettlement`, never by combat UI.

**Tech Stack:** Godot 4.7, GDScript, JSON content definitions, existing custom headless tests, existing `ContentCatalog`/campaign/character/save foundation.

## Global Constraints

- Preserve the final target of 6 regions, 30 missions, 5 characters, 10 mastery levels, and 30-40 hours of primary completion time.
- This plan builds the reusable shell and the first playable campaign loop; mission-specific objective mechanics are the next independent plan.
- Boot must open the campaign map instead of starting combat.
- Runtime level and upgrade state reset for every mission; character mastery persists independently.
- Only unlocked missions and unlocked characters can start a run.
- `mechanism_walker` starts with `mechanism_crossbow`, not the legacy `flying_sword` default.
- Core mission/character references must validate before a battle scene enters the tree.
- All main touch targets are at least 48 logical pixels; mission nodes are at least 64 x 64.
- Preserve the four existing uncommitted starting-ward changes and do not stage them with campaign commits.

---

## File Structure

- Create `scripts/core/run_context_builder.gd`: pure validation and construction of per-run input.
- Create `scripts/core/app_flow.gd`: owns catalog/save services and screen transitions.
- Modify `scenes/boot/Boot.tscn`: replace the direct `Game` instance with `AppFlow` plus a screen container.
- Create `scripts/ui/campaign_map.gd` and `scenes/ui/CampaignMap.tscn`: six-region mission navigation.
- Create `scripts/ui/character_select.gd` and `scenes/ui/CharacterSelect.tscn`: character/mastery/loadout confirmation.
- Create `scripts/systems/campaign_settlement.gd`: pure one-run progression transaction.
- Modify `scripts/core/game_loop.gd`: consume run context, use the selected starting weapon, and emit a single run result.
- Modify `scripts/systems/enemy_director.gd`: accept mission encounter-card IDs and seed.
- Modify `scripts/ui/settlement_panel.gd` and `scenes/ui/SettlementPanel.tscn`: add campaign/mastery feedback and a return-to-map action.
- Create `tests/test_run_context_builder.gd`, `tests/test_campaign_map.gd`, `tests/test_character_select.gd`, `tests/test_campaign_settlement.gd`, and `tests/test_app_flow.gd`.
- Modify `tests/test_game_loop_summary.gd`, `tests/test_enemy_director.gd`, `tests/test_settlement_panel.gd`, `tests/test_game_scene_composition.gd`, and `tests/run_all_tests.gd`.

---

### Task 1: Validated Run Context

**Files:**
- Create: `scripts/core/run_context_builder.gd`
- Create: `tests/test_run_context_builder.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: a mission definition, character definition, difficulty mark, seed, battle database, and content catalog.
- Produces: `build(...) -> { "ok": bool, "context": Dictionary, "errors": Array[String] }`.
- The context contains `mission_id`, `chapter_id`, `character_id`, `starting_weapon_id`, `mission_seed`, `difficulty_mark`, `mission_rules`, `encounter_deck_id`, `environment_id`, and `boss_id`.

- [ ] **Step 1: Write the failing context test**

Create a real-catalog test using the existing Red Wastes survival mission and mechanism walker:

```gdscript
var builder = load("res://scripts/core/run_context_builder.gd").new()
var result: Dictionary = builder.build(
    catalog.get_mission("red_wastes_survival"),
    catalog.get_character("mechanism_walker"),
    0,
    24680,
    battle_db,
    catalog,
)
runner.assert_true(result["ok"], "valid campaign selections should build a run context")
runner.assert_eq(result["context"]["starting_weapon_id"], "mechanism_crossbow", "run context should use the selected character weapon")
runner.assert_eq(result["context"]["mission_rules"]["kind"], "survive", "run context should copy mission rules")
runner.assert_eq(result["context"]["mission_seed"], 24680, "explicit mission seed should remain deterministic")
```

Also pass empty mission, unknown weapon, unknown encounter deck, and negative mark fixtures; each must return `ok == false`, an empty context, and a precise error string.

- [ ] **Step 2: Run the suite and verify RED**

Run the full headless test command. Expected: failure because `run_context_builder.gd` does not exist.

- [ ] **Step 3: Implement the minimal builder**

Implement this public contract:

```gdscript
extends RefCounted
class_name RunContextBuilder

func build(
    mission: Dictionary,
    character: Dictionary,
    difficulty_mark: int,
    seed_value: int,
    battle_database: Object,
    content_catalog: Object,
) -> Dictionary:
    var errors: Array[String] = []
    var mission_id := String(mission.get("id", ""))
    var character_id := String(character.get("id", ""))
    var weapon_id := String(character.get("starting_weapon_id", ""))
    var deck_id := String(mission.get("encounter_deck_id", ""))
    var environment_id := String(mission.get("environment_id", ""))
    if mission_id == "": errors.append("missing_mission")
    if character_id == "": errors.append("missing_character")
    if difficulty_mark < 0: errors.append("invalid_difficulty_mark")
    if battle_database == null or not battle_database.has_weapon(weapon_id): errors.append("missing_starting_weapon")
    if content_catalog == null or not content_catalog.get_encounter_decks().has(deck_id): errors.append("missing_encounter_deck")
    if content_catalog == null or not content_catalog.get_environments().has(environment_id): errors.append("missing_environment")
    if not errors.is_empty():
        return {"ok": false, "context": {}, "errors": errors}
    return {
        "ok": true,
        "context": {
            "mission_id": mission_id,
            "chapter_id": String(mission.get("chapter_id", "")),
            "character_id": character_id,
            "starting_weapon_id": weapon_id,
            "mission_seed": seed_value if seed_value != 0 else Time.get_ticks_usec(),
            "difficulty_mark": difficulty_mark,
            "mission_rules": Dictionary(mission.get("objective", {})).duplicate(true),
            "encounter_deck_id": deck_id,
            "environment_id": environment_id,
            "boss_id": String(mission.get("boss_id", "")),
        },
        "errors": [],
    }
```

Return deep duplicates so callers cannot mutate source content through the context.

- [ ] **Step 4: Verify and commit**

Run all tests, stage only Task 1 files, and commit `feat: add validated campaign run context`.

---

### Task 2: Campaign Map View And Interaction

**Files:**
- Create: `scripts/ui/campaign_map.gd`
- Create: `scenes/ui/CampaignMap.tscn`
- Create: `tests/test_campaign_map.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: chapter map, mission map, campaign save state, and `CampaignProgression`.
- Produces: `configure(chapters, missions, campaign_state) -> void`.
- Emits: `mission_selected(mission_id: String)` only for available/completed/mastered nodes.

- [ ] **Step 1: Write the failing map test**

Instantiate the formal scene, configure it from the real catalog and default save, then assert:

```gdscript
runner.assert_eq(map.get_chapter_count(), 6, "campaign map should show six regions")
runner.assert_eq(map.get_mission_count("red_wastes"), 5, "Red Wastes should show five mission nodes")
runner.assert_eq(map.get_mission_state("red_wastes_survival"), "available", "default mission should be available")
runner.assert_eq(map.get_mission_state("red_wastes_seal"), "locked", "next mission should remain locked")
runner.assert_true(map.get_mission_button("red_wastes_survival").custom_minimum_size.x >= 64.0, "mission touch target should be at least 64 pixels")
```

Connect `mission_selected`, press the available button, and assert one emission. Press the locked button and assert no second emission.

- [ ] **Step 2: Run tests and verify RED**

Expected: missing scene/script failure.

- [ ] **Step 3: Build the mobile scene**

Create this node structure with anchors filling the viewport:

```text
CampaignMap (Control, script)
  Background (ColorRect)
  MarginContainer
    VBoxContainer
      Header (HBoxContainer)
        TitleLabel
        MaterialsLabel
        DemonCoresLabel
      ChapterScroll (ScrollContainer)
        ChapterList (VBoxContainer)
      MissionDetail (PanelContainer)
        DetailVBox
          MissionNameLabel
          MissionDescriptionLabel
          MissionRuleLabel
          MissionRewardLabel
          SelectButton
```

Use a dark stone palette, cyan/gold accents matching current weapon/UI art, 16-pixel outer margins, 12-pixel list separation, and a minimum 56-pixel `SelectButton` height.

- [ ] **Step 4: Implement map presentation**

`configure` sorts chapters and missions by numeric `order`. Create one chapter panel per region and five mission buttons for implemented Red Wastes content. For unimplemented chapters, show one disabled chapter row with `尚未开放` and retain its formal name. Button labels include mission order, Chinese name, type label, and state label. Store IDs with `set_meta("mission_id", mission_id)`.

Expose test-friendly queries:

```gdscript
func get_chapter_count() -> int
func get_mission_count(chapter_id: String) -> int
func get_mission_state(mission_id: String) -> String
func get_mission_button(mission_id: String) -> Button
```

Selecting a valid node fills the detail card; pressing `SelectButton` emits the currently selected mission ID. Locked nodes update detail text with their prerequisite and keep `SelectButton.disabled = true`.

- [ ] **Step 5: Verify and commit**

Run all tests and a 720 x 1280 scene smoke. Commit Task 2 as `feat: add campaign map screen`.

---

### Task 3: Character Selection And Mastery Display

**Files:**
- Create: `scripts/ui/character_select.gd`
- Create: `scenes/ui/CharacterSelect.tscn`
- Create: `tests/test_character_select.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: selected mission, character definitions, character save state.
- Produces: `configure(mission, characters, characters_state) -> void`.
- Emits: `start_requested(character_id: String)` and `back_requested`.

- [ ] **Step 1: Write failing selection tests**

Using the real mechanism walker definition, assert the formal scene shows `机关行者`, `Lv.1`, the `机关连弩` starting weapon name, the three build tags, and a start button at least 56 pixels tall. Add a locked fixture and assert its start action is disabled and pressing it emits nothing.

- [ ] **Step 2: Run tests and verify RED**

Expected: missing scene/script.

- [ ] **Step 3: Create the scene**

Use this exact structure:

```text
CharacterSelect (Control, script)
  Background (ColorRect)
  MarginContainer
    VBoxContainer
      Header (HBoxContainer: BackButton, MissionLabel)
      CharacterScroll (ScrollContainer)
        CharacterList (HBoxContainer)
      CharacterDetail (PanelContainer)
        DetailVBox (Portrait, NameLabel, MasteryLabel, MasteryBar, WeaponLabel, TalentLabel, TagsLabel)
      StartButton
```

The portrait is contained within 240 x 320 logical pixels with `expand_mode = IGNORE_SIZE` and keep-aspect-centered stretch. Buttons have at least 56-pixel height.

- [ ] **Step 4: Implement selection behavior**

Sort characters by display name for now; later content can add explicit order. Only IDs in `characters_state.unlocked_ids` can start. Mastery display reads `mastery_levels` and `mastery_experience`; calculate current/next threshold from `CharacterProgression.MASTERY_THRESHOLDS`. The start button emits the selected unlocked ID once.

Expose:

```gdscript
func get_selected_character_id() -> String
func get_character_button(character_id: String) -> Button
func is_start_enabled() -> bool
```

- [ ] **Step 5: Verify and commit**

Run all tests and commit `feat: add character selection screen`.

---

### Task 4: App Flow And Boot Navigation

**Files:**
- Create: `scripts/core/app_flow.gd`
- Modify: `scenes/boot/Boot.tscn`
- Create: `tests/test_app_flow.gd`
- Modify: `tests/test_game_scene_composition.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Owns: one `GameDatabase`, `ContentCatalog`, `SaveSystem`, `CampaignProgression`, and `RunContextBuilder`.
- Produces transitions: map -> character selection -> configured game -> map.

- [ ] **Step 1: Write failing boot/navigation tests**

Instantiate `Boot.tscn`, wait one process frame, and assert `Screen/CampaignMap` exists while no `Game` exists. Emit the default mission selection and assert `Screen/CharacterSelect` replaces the map. Emit back and assert the map returns. Select the mission again and emit start for mechanism walker; assert a `Game` instance exists and its stored context contains the selected mission/character.

- [ ] **Step 2: Run tests and verify RED**

Expected: Boot still contains the direct game instance.

- [ ] **Step 3: Implement `AppFlow`**

Use exported packed scenes for map, character select, and game. `show_campaign_map` and `show_character_select` clear only the screen container. `start_selected_run` builds the context before adding the `Game` instance to the tree:

```gdscript
var game = game_scene.instantiate()
if not game.has_method("configure_run") or not game.configure_run(build["context"]):
    flow_error.emit("invalid_game_configuration")
    return false
_replace_screen(game)
return true
```

Load and configure the save service once. Keep `selected_mission_id` and `selected_id` in save v2 when a valid choice is made.

- [ ] **Step 4: Replace Boot composition**

`Boot.tscn` becomes:

```text
Boot (Node, app_flow.gd)
  Screen (Node)
```

Assign the three formal packed scenes as exported resources. Do not autoload global singletons.

- [ ] **Step 5: Verify and commit**

Run all tests plus `--headless --path . --quit-after 600`. Commit `feat: add campaign app flow`.

---

### Task 5: Configure Combat From The Selected Mission And Character

**Files:**
- Modify: `scripts/core/game_loop.gd`
- Modify: `scripts/systems/enemy_director.gd`
- Modify: `tests/test_game_loop_summary.gd`
- Modify: `tests/test_enemy_director.gd`

**Interfaces:**
- Produces: `GameLoop.configure_run(context: Dictionary) -> bool` before `_ready`.
- Produces: `GameLoop.get_run_context() -> Dictionary`.
- Extends: `EnemyDirector.configure(database, player, allowed_encounter_ids = [], seed_value = 0)`.

- [ ] **Step 1: Write failing combat-context tests**

Instantiate `Game.tscn` outside the tree, configure it with a valid context, add it to the tree, then assert runtime state and `WeaponSystem` own only `mechanism_crossbow` at level 1. Assert `ExperienceSystem.level == 1` and empty upgrade stacks. Free it, instantiate a second run, and assert those values reset again.

Add an enemy-director test with two allowed encounter IDs and assert every configured encounter-bag card belongs to that allowlist; assert the explicit seed is used.

- [ ] **Step 2: Run tests and verify RED**

Expected: `configure_run` missing and legacy flying sword still starts.

- [ ] **Step 3: Implement context configuration**

Store a deep duplicate before `_ready`. Reject missing required string fields. In `_ready`, fall back to the default catalog mission/character only when the scene is launched directly by a developer smoke test; campaign flow must always pass a valid context.

Replace the hard-coded runtime state and weapon initialization with:

```gdscript
runtime_state = {
    "owned_weapons": {String(run_context["starting_weapon_id"]): 1},
    "upgrade_stacks": {},
    "max_weapon_slots": 4,
    "character_id": String(run_context["character_id"]),
}
weapon_system.add_weapon(database.get_weapon(String(run_context["starting_weapon_id"])))
```

Filter encounter definitions using the context deck and pass the mission seed to the director. The legacy timed wave list remains only as the survival vertical-slice schedule until mission objectives replace it in the next plan.

- [ ] **Step 4: Verify and commit**

Run all tests and both weapon/encounter simulators. Commit `feat: configure combat from campaign selection`.

---

### Task 6: One-Time Campaign Settlement Transaction

**Files:**
- Create: `scripts/systems/campaign_settlement.gd`
- Create: `tests/test_campaign_settlement.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `scripts/ui/settlement_panel.gd`
- Modify: `scenes/ui/SettlementPanel.tscn`
- Modify: `tests/test_game_loop_summary.gd`
- Modify: `tests/test_settlement_panel.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: save v2, run context, run summary, mission/character/chapter maps.
- Produces: `apply(save_data, run_context, run_summary, missions, chapters) -> { save_data, run_result }`.
- Emits: `GameLoop.run_concluded(run_result: Dictionary)` only after settlement save succeeds.
- Emits: `SettlementPanel.continue_requested`.

- [ ] **Step 1: Write failing transaction tests**

Cover first victory, repeat victory, failure, and duplicate application. A first survival victory must:

```gdscript
runner.assert_true(result["run_result"]["victory"], "boss/survival completion should report victory")
runner.assert_true(result["run_result"]["first_completion"], "first victory should report first completion")
runner.assert_true(result["save_data"]["campaign"]["unlocked_missions"].has("red_wastes_seal"), "first victory should unlock the next mission")
runner.assert_true(result["save_data"]["characters"]["mastery_experience"]["mechanism_walker"] > 0, "settlement should grant selected character mastery")
```

Repeat victory uses `repeat_reward`, not `first_reward`, and reports no new unlock. Failure grants 35%-55% mastery based on `progress_ratio`, does not complete the mission, and still grants existing combat materials. An already-applied `run_id` returns `error: "duplicate_settlement"` without changing the save.

- [ ] **Step 2: Run tests and verify RED**

Expected: missing `campaign_settlement.gd`.

- [ ] **Step 3: Implement the pure transaction**

Deep-duplicate the save. Build `run_id` from mission ID, character ID, seed, and a terminal timestamp supplied by `GameLoop`; store the most recent ID in `save_data.last_settled_run_id`. Use `CampaignProgression.apply_victory` only for victory. Use `CharacterProgression.calculate_mission_experience` for both outcomes. Add mission reward materials/cores exactly once and return display-ready deltas.

- [ ] **Step 4: Extend the settlement panel**

Add `MissionProgressLabel`, `MasteryLabel`, `UnlockLabel`, and a `ContinueButton` with text `返回地图` and at least 56-pixel height. Keep equipment upgrade rows. `show_campaign_result(run_result)` fills the new labels; `ContinueButton` emits `continue_requested` and ignores double presses while disabled.

- [ ] **Step 5: Wire GameLoop and AppFlow**

GameLoop creates one terminal result, saves it once, displays it, and emits `run_concluded` after success. AppFlow caches the emitted result; the panel continue action unpauses the tree, frees the game, reloads normalized save data, and shows the campaign map with the newly unlocked node.

- [ ] **Step 6: Verify and commit**

Run all tests, scene smoke, `git diff --check`, and commit `feat: persist campaign run settlement`.

---

### Task 7: End-To-End Campaign Shell Verification

**Files:**
- Modify: `tests/test_app_flow.gd`
- Modify: `tests/test_game_scene_composition.gd`
- Update: `docs/superpowers/plans/2026-07-13-campaign-shell-vertical-slice.md` checkboxes only after evidence exists.

**Interfaces:**
- Verifies the completed shell; produces no new runtime API.

- [ ] **Step 1: Add the end-to-end smoke path**

Use a temporary save path and actual formal scenes. Verify Boot opens map; select survival; select mechanism walker; assert combat context and crossbow; call `record_player_defeat`; assert settlement shows failure; trigger continue; assert map returns and survival remains available. Repeat with a synthetic victory terminal summary; assert the seal mission becomes available and mastery XP appears in character selection.

- [ ] **Step 2: Run complete verification**

Run:

```powershell
& $godot --headless --path . --script res://tests/run_all_tests.gd
& $godot --headless --path . --script res://tools/simulate_weapons.gd
& $godot --headless --path . --script res://tools/simulate_encounters.gd
& $godot --headless --path . --quit-after 600
git diff --check
```

Expected: all commands exit 0, tests print `All tests passed.`, both simulations report no validation failures, and no `SCRIPT ERROR` appears.

- [ ] **Step 3: Manual mobile-size check**

Run the project at 720 x 1280 and verify campaign map scrolling, 64-pixel mission buttons, character portrait containment, 56-pixel primary actions, back navigation, combat startup, settlement, and return-to-map. Confirm the starting ward remains behind and outside the player after the earlier visual fix.

- [ ] **Step 4: Commit verification updates**

Commit only the plan checkbox/test evidence update as `test: verify campaign shell vertical slice` if runtime changes were already committed per task.

---

## Plan Self-Review

- Spec coverage: covers navigation, map, character selection/mastery presentation, validated context, selected starting weapon, one-time settlement, and return-to-map. The five distinct Red Wastes objective mechanics remain the next plan, as required by the design's implementation order.
- Final-scope fidelity: all APIs and UI are built for six chapters and multiple characters; no temporary direct-to-game or single-character branch is introduced. The complete 30-mission/5-character target remains active after this independently testable shell.
- Placeholder scan: every task names concrete files, interfaces, assertions, commands, and expected results.
- Type consistency: IDs are strings; catalogs and save sections are dictionaries; run context/result are deep-duplicated dictionaries; signals carry exact dictionary/string payloads.
- Worktree safety: commits stage explicit task files and exclude the existing ward visual changes until they are committed separately.
