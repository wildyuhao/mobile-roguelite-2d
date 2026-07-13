# Campaign Progression Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data, validation, save migration, mission unlock, and character mastery foundation required by the campaign map vertical slice.

**Architecture:** Keep long-term progression outside `GameLoop`. A new `ContentCatalog` loads campaign-facing data and validates references against the existing `GameDatabase`; `CampaignProgression` and `CharacterProgression` remain pure `RefCounted` calculators; `SaveSystem` owns version-2 migration and normalization. UI and scene navigation consume these interfaces in a separate plan.

**Tech Stack:** Godot 4.7, GDScript, JSON content definitions, the existing custom headless test runner.

## Global Constraints

- Preserve all existing version-1 materials, equipment levels, unlocked equipment, and settings.
- Default progression unlocks only `mechanism_walker` and `red_wastes_survival`.
- Campaign missions use stable IDs and data references; no chapter-specific branches in runtime code.
- Mission state is one of `locked`, `available`, `completed`, or `mastered`.
- Character mastery is independent per character, bounded to levels 1-10, and grants no unbounded numeric power.
- Failure mastery rewards remain between 35% and 55% of the equivalent victory reward.
- Existing uncommitted starting-ward files are outside this plan and must not be staged or modified.

---

## File Structure

- Create `data/campaign/chapters.json`: six ordered region definitions and implementation flags.
- Create `data/campaign/environments.json`: campaign environment metadata and formal texture references.
- Create `data/campaign/encounter_decks.json`: stable deck IDs referencing existing encounter cards.
- Create `data/missions/red_wastes.json`: the first chapter's five ordered mission definitions.
- Create `data/characters/mechanism_walker.json`: the first playable character and ten mastery rewards.
- Create `scripts/data/content_catalog.gd`: campaign content loading and cross-catalog validation.
- Create `scripts/systems/campaign_progression.gd`: pure mission state and unlock calculation.
- Create `scripts/systems/character_progression.gd`: pure mastery XP, level, and reward calculation.
- Modify `scripts/systems/save_system.gd`: version-2 defaults, migration, and known-ID normalization.
- Create `tests/test_content_catalog.gd`: schema, ordering, and reference coverage.
- Create `tests/test_campaign_progression.gd`: normal, Boss, repeat, and mastery state coverage.
- Create `tests/test_character_progression.gd`: reward ratio, independent XP, and level-cap coverage.
- Modify `tests/test_save_system.gd`: version-1 migration and invalid-selection repair coverage.
- Modify `tests/run_all_tests.gd`: register the three new test files.

---

### Task 1: Campaign Content Catalog

**Files:**
- Create: `data/campaign/chapters.json`
- Create: `data/campaign/environments.json`
- Create: `data/campaign/encounter_decks.json`
- Create: `data/missions/red_wastes.json`
- Create: `data/characters/mechanism_walker.json`
- Create: `scripts/data/content_catalog.gd`
- Create: `tests/test_content_catalog.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `GameDatabase.get_weapons()`, `get_enemies()`, and `get_encounters()`.
- Produces: `ContentCatalog.load_all(battle_database: Object) -> bool`.
- Produces: `get_chapters()`, `get_missions()`, `get_characters()`, `get_environments()`, and `get_encounter_decks()`, each returning a `Dictionary` keyed by stable ID.

- [ ] **Step 1: Write the failing catalog test**

Create `tests/test_content_catalog.gd`. Load `GameDatabase`, then `ContentCatalog`, and assert:

```gdscript
var battle_db = load("res://scripts/data/game_database.gd").new()
runner.assert_true(battle_db.load_all(), "battle catalog should load first")
var catalog = load("res://scripts/data/content_catalog.gd").new()
runner.assert_true(catalog.load_all(battle_db), "campaign catalog should validate")
runner.assert_eq(catalog.get_chapters().size(), 6, "campaign should expose six ordered chapters")
runner.assert_eq(catalog.get_missions().size(), 5, "first campaign slice should expose five missions")
runner.assert_eq(catalog.get_characters().size(), 1, "first campaign slice should expose the default character")

var expected_types := ["survival", "seal", "hunt", "mutation", "boss"]
for order in range(1, 6):
    var mission: Dictionary = catalog.get_mission_by_chapter_order("red_wastes", order)
    runner.assert_eq(mission.get("type", ""), expected_types[order - 1], "mission order should match the chapter contract")

var character: Dictionary = catalog.get_character("mechanism_walker")
runner.assert_eq(character.get("starting_weapon_id", ""), "mechanism_crossbow", "default character should start with the crossbow")
runner.assert_eq(Array(character.get("mastery_rewards", [])).size(), 10, "character should define ten mastery rewards")
runner.assert_true(catalog.errors.is_empty(), "valid campaign content should produce no errors")
```

Register the test immediately after `test_game_database.gd` in `tests/run_all_tests.gd`.

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& $godot --headless --path . --script res://tests/run_all_tests.gd
```

Expected: failure because `content_catalog.gd` and campaign JSON files do not exist.

- [ ] **Step 3: Add the six chapter and shared campaign definitions**

Write `chapters.json` as an array with ordered IDs and names:

```json
[
  { "id": "red_wastes", "order": 1, "display_name": "赤土荒境", "implemented": true, "first_mission_id": "red_wastes_survival" },
  { "id": "bamboo_ruins", "order": 2, "display_name": "幽竹残林", "implemented": false, "first_mission_id": "" },
  { "id": "ghost_market", "order": 3, "display_name": "百鬼夜市", "implemented": false, "first_mission_id": "" },
  { "id": "underworld_tomb", "order": 4, "display_name": "黄泉机关冢", "implemented": false, "first_mission_id": "" },
  { "id": "thunder_altar", "order": 5, "display_name": "雷狱天坛", "implemented": false, "first_mission_id": "" },
  { "id": "rift_seal_platform", "order": 6, "display_name": "裂天封魔台", "implemented": false, "first_mission_id": "" }
]
```

Write one `red_wastes` environment using `res://art/environment/wasteland_ground_tile.png`, and one `red_wastes_deck` containing the seven existing encounter card IDs: `four_side_surround`, `wedge_charge`, `turret_escort`, `elite_lead`, `seal_contest`, `chest_ambush`, and `boss_vanguard`.

- [ ] **Step 4: Add the five Red Wastes missions**

Every mission in `red_wastes.json` must include `id`, `chapter_id`, `order`, `type`, `display_name`, `description`, `estimated_minutes`, `objective`, `environment_id`, `encounter_deck_id`, `boss_id`, `prerequisites`, `first_reward`, and `repeat_reward`.

Use this exact chain and objective contract:

| Order | ID | Type | Objective | Prerequisite |
|---|---|---|---|---|
| 1 | `red_wastes_survival` | `survival` | `{ "kind": "survive", "duration": 720 }` | none |
| 2 | `red_wastes_seal` | `seal` | `{ "kind": "seal_points", "count": 3, "hold_seconds": 25 }` | survival |
| 3 | `red_wastes_hunt` | `hunt` | `{ "kind": "elite_hunt", "count": 4 }` | seal |
| 4 | `red_wastes_mutation` | `mutation` | `{ "kind": "mutator_survival", "duration": 900, "mutators": ["swift"] }` | hunt |
| 5 | `red_wastes_boss` | `boss` | `{ "kind": "boss", "boss_id": "seal_boss" }` | mutation |

All five use `red_wastes` and `red_wastes_deck`; only the Boss mission sets top-level `boss_id` to `seal_boss`. First rewards grant materials plus one explicit unlock token; repeat rewards grant fewer materials, and hunt/Boss rewards include `demon_cores`.

- [ ] **Step 5: Add the default character**

Create `mechanism_walker.json` with:

```json
{
  "id": "mechanism_walker",
  "display_name": "机关行者",
  "description": "以机关连弩和模块强化维持稳定火力的均衡行者。",
  "starting_weapon_id": "mechanism_crossbow",
  "scene_path": "res://scenes/player/Player.tscn",
  "portrait_path": "res://art/characters/player/player_front.png",
  "base_stat_modifiers": {},
  "innate_talent_id": "mechanism_first_upgrade_haste",
  "active_skill_id": "mechanism_overdrive",
  "build_tags": ["均衡", "机关", "投射物"],
  "unlock_condition": { "kind": "default" },
  "mastery_rewards": [
    { "level": 1, "kind": "base_kit", "id": "mechanism_base_kit" },
    { "level": 2, "kind": "upgrade_unlock", "id": "mechanism_specialist_1" },
    { "level": 3, "kind": "loadout_unlock", "id": "mechanism_crossbow_start" },
    { "level": 4, "kind": "cosmetic", "id": "mechanism_portrait_1" },
    { "level": 5, "kind": "upgrade_unlock", "id": "mechanism_specialist_2" },
    { "level": 6, "kind": "passive_unlock", "id": "mechanism_passive_1" },
    { "level": 7, "kind": "cosmetic", "id": "mechanism_palette_1" },
    { "level": 8, "kind": "skill_variant", "id": "mechanism_overdrive_reset" },
    { "level": 9, "kind": "codex_challenge", "id": "mechanism_archive" },
    { "level": 10, "kind": "core_upgrade", "id": "mechanism_core_mastery" }
  ]
}
```

- [ ] **Step 6: Implement `ContentCatalog`**

Implement directory/array JSON loaders following `GameDatabase`. Convert every set to an ID map and collect all validation failures before returning. Validation must reject duplicate IDs, chapter order gaps, duplicate mission chapter/order pairs, missing chapter/environment/deck/prerequisite/Boss/weapon references, missing scene or texture resources, nonpositive mission duration/reward values, a first chapter that is not exactly the five required types, and characters without ten sequential mastery rewards.

Expose:

```gdscript
func load_all(battle_database: Object) -> bool
func get_chapters() -> Dictionary
func get_missions() -> Dictionary
func get_mission(id: String) -> Dictionary
func get_mission_by_chapter_order(chapter_id: String, order: int) -> Dictionary
func get_characters() -> Dictionary
func get_character(id: String) -> Dictionary
func get_environments() -> Dictionary
func get_encounter_decks() -> Dictionary
```

- [ ] **Step 7: Run catalog and full tests**

Run the full Godot test command. Expected: `All tests passed.` and no `SCRIPT ERROR` lines.

- [ ] **Step 8: Commit Task 1**

Stage only Task 1 files and commit:

```powershell
git commit -m "feat: add campaign content catalog"
```

---

### Task 2: Mission Unlock And Mastery State

**Files:**
- Create: `scripts/systems/campaign_progression.gd`
- Create: `tests/test_campaign_progression.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: mission and chapter maps from `ContentCatalog` plus `save["campaign"]`.
- Produces: `get_mission_state(mission_id, campaign, missions, chapters) -> String`.
- Produces: `apply_victory(campaign, mission_id, difficulty_mark, missions, chapters) -> Dictionary` with `campaign`, `first_completion`, `newly_unlocked`, and `mark_unlocked`.

- [ ] **Step 1: Write failing progression tests**

Cover default state, normal mission unlock, Boss chapter/mark unlock, repeat idempotency, and mastery:

```gdscript
var campaign := {
    "completed_missions": {},
    "unlocked_missions": ["red_wastes_survival"],
    "chapter_marks": {"red_wastes": 0},
    "selected_mission_id": "red_wastes_survival",
}
runner.assert_eq(system.get_mission_state("red_wastes_survival", campaign, missions, chapters), "available", "first mission should be available")
runner.assert_eq(system.get_mission_state("red_wastes_seal", campaign, missions, chapters), "locked", "second mission should be locked")

var first = system.apply_victory(campaign, "red_wastes_survival", 0, missions, chapters)
runner.assert_true(first["first_completion"], "first clear should be marked once")
runner.assert_true(first["newly_unlocked"].has("red_wastes_seal"), "normal clear should unlock the next node")
var repeat = system.apply_victory(first["campaign"], "red_wastes_survival", 0, missions, chapters)
runner.assert_true(not repeat["first_completion"], "repeat clear should not repeat first rewards")
runner.assert_true(repeat["newly_unlocked"].is_empty(), "repeat clear should not duplicate unlocks")
```

Use a small two-chapter fixture for the Boss test so completion unlocks the next chapter's first mission and raises the completed chapter's available mark to 1.

- [ ] **Step 2: Run tests and verify RED**

Expected: missing `campaign_progression.gd`.

- [ ] **Step 3: Implement pure progression logic**

Store `completed_missions` as `{ mission_id: highest_completed_mark }`. `get_mission_state` returns:

```gdscript
if not unlocked: "locked"
elif not completed: "available"
elif completed_mark >= current_chapter_mark: "mastered"
else: "completed"
```

`apply_victory` deep-duplicates input, clamps `difficulty_mark` to at least 0, raises only the completed mission's mark, and unlocks exactly one next mission. A Boss unlocks the next chapter's first mission and raises the completed chapter mark to at least 1. Unknown missions return the untouched campaign plus `error: "unknown_mission"`.

- [ ] **Step 4: Run tests and commit**

Run full Godot tests, stage only Task 2 files, and commit:

```powershell
git commit -m "feat: add campaign mission progression"
```

---

### Task 3: Character Mastery Progression

**Files:**
- Create: `scripts/systems/character_progression.gd`
- Create: `tests/test_character_progression.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `get_level_for_experience(experience: int) -> int`.
- Produces: `calculate_mission_experience(mission_type: String, victory: bool, progress_ratio: float, first_completion: bool) -> int`.
- Produces: `apply_experience(characters_state: Dictionary, character_id: String, amount: int) -> Dictionary`.

- [ ] **Step 1: Write failing mastery tests**

Assert the cumulative thresholds `[0, 100, 240, 430, 680, 990, 1360, 1790, 2280, 2830]`, level bounds 1-10, independent character maps, and capped level 10. For each mission type, assert failure XP divided by victory XP is between `0.35` and `0.55`; progress 0 uses 35% and progress 1 uses 55%. Assert first completion adds 25% of base victory XP only once when the caller passes `first_completion = true`.

- [ ] **Step 2: Run tests and verify RED**

Expected: missing `character_progression.gd`.

- [ ] **Step 3: Implement mastery calculations**

Use base victory XP:

```gdscript
const BASE_EXPERIENCE := {
    "survival": 100,
    "seal": 110,
    "hunt": 120,
    "mutation": 140,
    "boss": 200,
}
```

Victory returns base XP plus a rounded 25% first-completion bonus. Failure returns `round(base * lerp(0.35, 0.55, clamp(progress_ratio, 0, 1)))` and receives no first-completion bonus. `apply_experience` writes only the selected character's cumulative XP and derived level; unknown/empty IDs or nonpositive amounts return an unchanged duplicate.

- [ ] **Step 4: Run tests and commit**

Run full Godot tests, stage only Task 3 files, and commit:

```powershell
git commit -m "feat: add character mastery progression"
```

---

### Task 4: Version-2 Save Migration And Normalization

**Files:**
- Modify: `scripts/systems/save_system.gd`
- Modify: `tests/test_save_system.gd`

**Interfaces:**
- Produces: `configure_content_ids(mission_ids: Array[String], character_ids: Array[String], chapter_ids: Array[String]) -> void`.
- Preserves: `create_default_save`, `load_game`, `save_game`, and `delete_save`.

- [ ] **Step 1: Extend save tests first**

Configure known IDs with the five Red Wastes missions, `mechanism_walker`, and `red_wastes`. Assert a default save has version 2 and exact campaign/character defaults. Write a version-1 fixture containing materials, equipment levels, unlocks, and settings; after load, assert all old values remain and all version-2 defaults exist. Write a malformed version-2 fixture containing unknown selected IDs and mixed field types; assert selection falls back to the default IDs, unknown completion/character entries are removed, materials remain nonnegative, and level/XP values normalize to valid integers.

- [ ] **Step 2: Run tests and verify RED**

Expected: version remains 1 and campaign/character fields are missing.

- [ ] **Step 3: Implement v2 defaults and migration**

Add:

```gdscript
const CURRENT_VERSION := 2
const DEFAULT_CHARACTER_ID := "mechanism_walker"
const DEFAULT_MISSION_ID := "red_wastes_survival"
const DEFAULT_CHAPTER_ID := "red_wastes"
```

The default shape is:

```gdscript
{
    "version": 2,
    "materials": 0,
    "equipment_levels": {},
    "unlocked_equipment": DEFAULT_UNLOCKED_EQUIPMENT.duplicate(),
    "settings": {"music_volume": 0.8, "sfx_volume": 0.8},
    "campaign": {
        "completed_missions": {},
        "unlocked_missions": [DEFAULT_MISSION_ID],
        "chapter_marks": {DEFAULT_CHAPTER_ID: 0},
        "selected_mission_id": DEFAULT_MISSION_ID,
    },
    "characters": {
        "unlocked_ids": [DEFAULT_CHARACTER_ID],
        "mastery_levels": {DEFAULT_CHARACTER_ID: 1},
        "mastery_experience": {DEFAULT_CHARACTER_ID: 0},
        "selected_id": DEFAULT_CHARACTER_ID,
        "starting_loadouts": {},
    },
    "codex": {"unlocked_entries": []},
    "resources": {"demon_cores": 0},
}
```

Normalize from a fresh default and copy only valid typed legacy fields. Deduplicate string arrays, clamp resources to nonnegative integers, filter campaign and character dictionaries against configured known IDs, ensure defaults remain unlocked, derive missing mastery levels from normalized XP only when `CharacterProgression` is available, and set `version` to 2. Keep corrupt source files untouched; `load_game` may return a default but must not delete the source.

- [ ] **Step 4: Run full verification and commit**

Run:

```powershell
& $godot --headless --path . --script res://tests/run_all_tests.gd
& $godot --headless --path . --script res://tools/simulate_encounters.gd
& $godot --headless --path . --quit-after 600
git diff --check
```

Expected: all commands exit 0, tests print `All tests passed.`, and no `SCRIPT ERROR` appears. Stage only Task 4 files and commit:

```powershell
git commit -m "feat: migrate saves to campaign version two"
```

---

## Plan Self-Review

- Spec coverage: this plan covers implementation order item 1 only: campaign/character content, progression pure logic, and save v2. `AppFlow`, map UI, character selection UI, `RunContext`, `RunResult`, task objectives, and the other four character kits remain explicitly outside this independently testable foundation.
- Placeholder scan: complete; every implementation step contains concrete inputs, outputs, commands, and expected results.
- Type consistency: campaign completion uses `Dictionary[String, int]` semantics throughout; content maps are keyed dictionaries; mastery levels are derived integers from cumulative XP.
- Worktree safety: all commands stage explicit paths and exclude the four pre-existing starting-ward changes.
