# Core Playable Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first testable Godot 4 foundation for the mobile survivor roguelite: project skeleton, data loading, upgrade logic, player/enemy combat components, first weapon, and a minimal playable run scene.

**Architecture:** Use Godot scenes for presentation, focused GDScript systems for gameplay rules, and JSON data files for weapons, upgrades, enemies, equipment, and waves. Keep the first loop small but real: one player, one basic enemy, one weapon, experience pickup, and level-up choice generation.

**Tech Stack:** Godot 4.3 or newer, GDScript, JSON content files, PowerShell commands on Windows, Git.

---

## Scope

This plan implements the foundation for Week 1 and the first half of Week 2 from the design spec. It does not implement final generated art, all four weapons, boss combat, Android export, or full meta progression. Those are separate plans after this foundation is verified.

## Prerequisite

Godot is not currently available as `godot` or `godot4` in PATH on this machine. Before running Godot commands, install Godot 4.3+ or point `$env:GODOT_BIN` to the installed executable.

Example PowerShell session:

```powershell
$env:GODOT_BIN = "C:\Program Files\Godot\Godot_v4.3-stable_win64.exe"
& $env:GODOT_BIN --version
```

Expected output: a Godot 4.x version string.

## File Structure

Create these files and directories:

```text
project.godot
.gitignore
README.md
data/
  enemies/basic_demon.json
  equipment/starter_equipment.json
  upgrades/core_upgrades.json
  waves/first_run.json
  weapons/flying_sword.json
scenes/
  boot/Boot.tscn
  game/Game.tscn
  player/Player.tscn
  enemies/BasicDemon.tscn
  weapons/Projectile.tscn
  ui/HUD.tscn
  ui/UpgradeChoicePanel.tscn
scripts/
  core/constants.gd
  core/game_loop.gd
  core/test_runner.gd
  components/health_component.gd
  components/hitbox_component.gd
  components/hurtbox_component.gd
  data/game_database.gd
  player/player_controller.gd
  enemies/enemy_agent.gd
  systems/enemy_director.gd
  systems/experience_system.gd
  systems/upgrade_system.gd
  systems/weapon_system.gd
  weapons/projectile.gd
  ui/hud.gd
  ui/upgrade_choice_panel.gd
tests/
  run_all_tests.gd
  test_game_database.gd
  test_health_component.gd
  test_upgrade_system.gd
  test_weapon_system.gd
```

Responsibility map:

- `game_database.gd`: loads JSON files and exposes content dictionaries by id.
- `upgrade_system.gd`: produces valid three-choice upgrade options from database plus runtime state.
- `weapon_system.gd`: owns weapon cooldowns and projectile spawn intent.
- `enemy_director.gd`: spawns enemies from wave timing definitions.
- `game_loop.gd`: wires run state, player, enemies, experience, upgrades, and win/loss flow.
- `health_component.gd`: reusable health and damage rules.
- `player_controller.gd`: player movement and input.
- `enemy_agent.gd`: simple chase behavior.
- `tests/run_all_tests.gd`: headless test entrypoint.

## Task 1: Project Skeleton And Headless Test Runner

**Files:**
- Create: `project.godot`
- Create: `.gitignore`
- Create: `README.md`
- Create: `scripts/core/constants.gd`
- Create: `scripts/core/test_runner.gd`
- Create: `tests/run_all_tests.gd`

- [ ] **Step 1: Create the Godot project file**

Create `project.godot`:

```ini
; Engine configuration file.
; It is best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.

config_version=5

[application]

config/name="Fuji Xingzhe"
run/main_scene="res://scenes/boot/Boot.tscn"
config/features=PackedStringArray("4.3", "Mobile")

[display]

window/size/viewport_width=720
window/size/viewport_height=1280
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]

move_left={
"deadzone": 0.2,
"events": []
}
move_right={
"deadzone": 0.2,
"events": []
}
move_up={
"deadzone": 0.2,
"events": []
}
move_down={
"deadzone": 0.2,
"events": []
}
```

- [ ] **Step 2: Create ignore rules**

Create `.gitignore`:

```gitignore
.godot/
.import/
*.tmp
*.translation
export/
builds/
```

- [ ] **Step 3: Create the README**

Create `README.md`:

```markdown
# Fuji Xingzhe

Mobile 2D survivor roguelite built with Godot 4 and GDScript.

## Local Setup

Set a Godot executable path before running commands:

```powershell
$env:GODOT_BIN = "C:\Program Files\Godot\Godot_v4.3-stable_win64.exe"
& $env:GODOT_BIN --version
```

Run all headless tests:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```
```

- [ ] **Step 4: Add shared constants**

Create `scripts/core/constants.gd`:

```gdscript
extends RefCounted
class_name GameConstants

const PLAYER_GROUP := "player"
const ENEMY_GROUP := "enemy"
const PROJECTILE_GROUP := "projectile"
const PICKUP_GROUP := "pickup"

const DATA_ROOT := "res://data"
const STARTING_WEAPON_ID := "flying_sword"
```

- [ ] **Step 5: Add the test runner helper**

Create `scripts/core/test_runner.gd`:

```gdscript
extends RefCounted
class_name TestRunner

var failures: Array[String] = []

func assert_true(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s Expected=%s Actual=%s" % [message, str(expected), str(actual)])

func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if abs(actual - expected) > tolerance:
		failures.append("%s Expected=%s Actual=%s Tolerance=%s" % [message, expected, actual, tolerance])

func has_failures() -> bool:
	return not failures.is_empty()

func print_failures() -> void:
	for failure in failures:
		push_error(failure)
```

- [ ] **Step 6: Add the test entrypoint**

Create `tests/run_all_tests.gd`:

```gdscript
extends SceneTree

const TestRunner := preload("res://scripts/core/test_runner.gd")

const TEST_SCRIPTS := [
	"res://tests/test_game_database.gd",
	"res://tests/test_health_component.gd",
	"res://tests/test_upgrade_system.gd",
	"res://tests/test_weapon_system.gd",
]

func _initialize() -> void:
	var runner := TestRunner.new()
	for script_path in TEST_SCRIPTS:
		if not ResourceLoader.exists(script_path):
			runner.assert_true(false, "Missing test script: %s" % script_path)
			continue

		var script := load(script_path)
		var test_case: Object = script.new()
		if not test_case.has_method("run"):
			runner.assert_true(false, "Test script has no run method: %s" % script_path)
			continue

		test_case.run(runner)

	if runner.has_failures():
		runner.print_failures()
		quit(1)
	else:
		print("All tests passed.")
		quit(0)
```

- [ ] **Step 7: Run tests to verify the runner reports missing tests**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because the four test scripts do not exist yet.

- [ ] **Step 8: Commit skeleton**

```powershell
git add project.godot .gitignore README.md scripts/core/constants.gd scripts/core/test_runner.gd tests/run_all_tests.gd
git commit -m "chore: add Godot project skeleton"
```

## Task 2: Data Files And Database Loader

**Files:**
- Create: `data/weapons/flying_sword.json`
- Create: `data/upgrades/core_upgrades.json`
- Create: `data/enemies/basic_demon.json`
- Create: `data/equipment/starter_equipment.json`
- Create: `data/waves/first_run.json`
- Create: `scripts/data/game_database.gd`
- Create: `tests/test_game_database.gd`

- [ ] **Step 1: Write the failing database test**

Create `tests/test_game_database.gd`:

```gdscript
extends RefCounted

const GameDatabase := preload("res://scripts/data/game_database.gd")

func run(runner) -> void:
	var db := GameDatabase.new()
	var result := db.load_all()

	runner.assert_true(result, "database load_all should return true")
	runner.assert_true(db.has_weapon("flying_sword"), "database should include flying_sword")
	runner.assert_eq(db.get_weapon("flying_sword")["display_name"], "Flying Sword", "flying_sword display name")
	runner.assert_true(db.has_enemy("basic_demon"), "database should include basic_demon")
	runner.assert_true(db.get_upgrades().size() >= 6, "database should include at least six upgrades")
	runner.assert_true(db.get_wave_events().size() >= 2, "database should include wave events")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because `scripts/data/game_database.gd` and data files do not exist.

- [ ] **Step 3: Add the first weapon data**

Create `data/weapons/flying_sword.json`:

```json
{
  "id": "flying_sword",
  "display_name": "Flying Sword",
  "description": "A talisman-guided blade that strikes the nearest demon.",
  "type": "projectile",
  "base_damage": 12,
  "cooldown": 0.9,
  "projectile_speed": 560,
  "range": 420,
  "pierce": 0,
  "max_level": 5,
  "level_modifiers": [
    { "level": 2, "base_damage": 16 },
    { "level": 3, "cooldown": 0.75 },
    { "level": 4, "pierce": 1 },
    { "level": 5, "projectile_count": 2 }
  ]
}
```

- [ ] **Step 4: Add core upgrade data**

Create `data/upgrades/core_upgrades.json`:

```json
[
  {
    "id": "weapon_damage_1",
    "display_name": "Sharpened Edge",
    "kind": "stat",
    "stat": "weapon_damage_multiplier",
    "value": 0.15,
    "max_stacks": 5
  },
  {
    "id": "cooldown_1",
    "display_name": "Quick Invocation",
    "kind": "stat",
    "stat": "weapon_cooldown_multiplier",
    "value": -0.08,
    "max_stacks": 5
  },
  {
    "id": "pickup_radius_1",
    "display_name": "Spirit Magnet",
    "kind": "stat",
    "stat": "pickup_radius",
    "value": 24,
    "max_stacks": 4
  },
  {
    "id": "move_speed_1",
    "display_name": "Cloudstep",
    "kind": "stat",
    "stat": "move_speed",
    "value": 24,
    "max_stacks": 4
  },
  {
    "id": "max_health_1",
    "display_name": "Jade Body",
    "kind": "stat",
    "stat": "max_health",
    "value": 12,
    "max_stacks": 5
  },
  {
    "id": "flying_sword_level",
    "display_name": "Flying Sword Mastery",
    "kind": "weapon_level",
    "weapon_id": "flying_sword",
    "max_stacks": 4
  }
]
```

- [ ] **Step 5: Add enemy data**

Create `data/enemies/basic_demon.json`:

```json
{
  "id": "basic_demon",
  "display_name": "Small Demon",
  "max_health": 24,
  "move_speed": 110,
  "contact_damage": 8,
  "experience_value": 1,
  "material_value": 1
}
```

- [ ] **Step 6: Add equipment data**

Create `data/equipment/starter_equipment.json`:

```json
[
  {
    "id": "talisman_robe",
    "display_name": "Talisman Robe",
    "stat_modifiers": { "max_health": 10 }
  },
  {
    "id": "sword_gourd",
    "display_name": "Sword Gourd",
    "starting_weapon_id": "flying_sword"
  }
]
```

- [ ] **Step 7: Add first wave data**

Create `data/waves/first_run.json`:

```json
[
  {
    "time": 0,
    "enemy_id": "basic_demon",
    "spawn_count": 4,
    "spawn_interval": 1.2
  },
  {
    "time": 60,
    "enemy_id": "basic_demon",
    "spawn_count": 8,
    "spawn_interval": 0.8
  }
]
```

- [ ] **Step 8: Implement the database loader**

Create `scripts/data/game_database.gd`:

```gdscript
extends RefCounted
class_name GameDatabase

var weapons: Dictionary = {}
var enemies: Dictionary = {}
var upgrades: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var wave_events: Array[Dictionary] = []
var errors: Array[String] = []

func load_all() -> bool:
	errors.clear()
	weapons = _load_directory_as_id_map("res://data/weapons")
	enemies = _load_directory_as_id_map("res://data/enemies")
	upgrades = _load_json_array("res://data/upgrades/core_upgrades.json")
	equipment = _load_json_array("res://data/equipment/starter_equipment.json")
	wave_events = _load_json_array("res://data/waves/first_run.json")
	return errors.is_empty()

func has_weapon(id: String) -> bool:
	return weapons.has(id)

func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

func has_enemy(id: String) -> bool:
	return enemies.has(id)

func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func get_upgrades() -> Array[Dictionary]:
	return upgrades

func get_equipment() -> Array[Dictionary]:
	return equipment

func get_wave_events() -> Array[Dictionary]:
	return wave_events

func _load_directory_as_id_map(path: String) -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		errors.append("Cannot open data directory: %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := "%s/%s" % [path, file_name]
			var data := _load_json_dictionary(full_path)
			if data.has("id"):
				result[data["id"]] = data
			else:
				errors.append("Data file has no id: %s" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _load_json_dictionary(path: String) -> Dictionary:
	var data := _load_json(path)
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Expected JSON object at %s" % path)
		return {}
	return data

func _load_json_array(path: String) -> Array[Dictionary]:
	var data := _load_json(path)
	if typeof(data) != TYPE_ARRAY:
		errors.append("Expected JSON array at %s" % path)
		return []

	var result: Array[Dictionary] = []
	for item in data:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item)
		else:
			errors.append("Expected dictionary item in %s" % path)
	return result

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("Missing JSON file: %s" % path)
		return null

	var text := FileAccess.get_file_as_string(path)
	var parsed := JSON.parse_string(text)
	if parsed == null:
		errors.append("Invalid JSON: %s" % path)
	return parsed
```

- [ ] **Step 9: Run tests to verify database passes and remaining tests are missing**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL only for missing `test_health_component.gd`, `test_upgrade_system.gd`, and `test_weapon_system.gd`.

- [ ] **Step 10: Commit data loader**

```powershell
git add data scripts/data tests/test_game_database.gd
git commit -m "feat: add data loader and starter content"
```

## Task 3: Health Component

**Files:**
- Create: `scripts/components/health_component.gd`
- Create: `tests/test_health_component.gd`

- [ ] **Step 1: Write the failing health test**

Create `tests/test_health_component.gd`:

```gdscript
extends RefCounted

const HealthComponent := preload("res://scripts/components/health_component.gd")

func run(runner) -> void:
	var health := HealthComponent.new()
	health.configure(30)

	runner.assert_eq(health.max_health, 30, "max health after configure")
	runner.assert_eq(health.current_health, 30, "current health after configure")

	health.take_damage(8)
	runner.assert_eq(health.current_health, 22, "damage reduces current health")
	runner.assert_true(not health.is_dead(), "health should not be dead yet")

	health.heal(5)
	runner.assert_eq(health.current_health, 27, "heal restores current health")

	health.take_damage(100)
	runner.assert_eq(health.current_health, 0, "damage clamps at zero")
	runner.assert_true(health.is_dead(), "health should be dead at zero")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because `health_component.gd` does not exist.

- [ ] **Step 3: Implement health component**

Create `scripts/components/health_component.gd`:

```gdscript
extends Node
class_name HealthComponent

signal died
signal damaged(amount: int)
signal healed(amount: int)

var max_health: int = 1
var current_health: int = 1

func configure(new_max_health: int) -> void:
	max_health = max(1, new_max_health)
	current_health = max_health

func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return

	current_health = max(0, current_health - amount)
	damaged.emit(amount)
	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return

	var before := current_health
	current_health = min(max_health, current_health + amount)
	healed.emit(current_health - before)

func is_dead() -> bool:
	return current_health <= 0
```

- [ ] **Step 4: Run tests**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL only for missing `test_upgrade_system.gd` and `test_weapon_system.gd`.

- [ ] **Step 5: Commit health component**

```powershell
git add scripts/components/health_component.gd tests/test_health_component.gd
git commit -m "feat: add health component"
```

## Task 4: Upgrade System

**Files:**
- Create: `scripts/systems/upgrade_system.gd`
- Create: `tests/test_upgrade_system.gd`

- [ ] **Step 1: Write the failing upgrade test**

Create `tests/test_upgrade_system.gd`:

```gdscript
extends RefCounted

const GameDatabase := preload("res://scripts/data/game_database.gd")
const UpgradeSystem := preload("res://scripts/systems/upgrade_system.gd")

func run(runner) -> void:
	var db := GameDatabase.new()
	runner.assert_true(db.load_all(), "database should load before upgrade tests")

	var system := UpgradeSystem.new()
	system.configure(db.get_upgrades())

	var runtime_state := {
		"owned_weapons": { "flying_sword": 1 },
		"upgrade_stacks": {}
	}

	var choices := system.get_choices(runtime_state, 3, 12345)
	runner.assert_eq(choices.size(), 3, "upgrade system should return three choices")
	runner.assert_true(_all_unique(choices), "choices should be unique")

	var damage_upgrade := _find_choice(choices, "weapon_damage_1")
	if damage_upgrade.is_empty():
		damage_upgrade = db.get_upgrades()[0]

	system.apply_upgrade(runtime_state, damage_upgrade)
	runner.assert_eq(runtime_state["upgrade_stacks"][damage_upgrade["id"]], 1, "selected upgrade stack increments")

func _all_unique(choices: Array[Dictionary]) -> bool:
	var seen := {}
	for choice in choices:
		if seen.has(choice["id"]):
			return false
		seen[choice["id"]] = true
	return true

func _find_choice(choices: Array[Dictionary], id: String) -> Dictionary:
	for choice in choices:
		if choice["id"] == id:
			return choice
	return {}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because `upgrade_system.gd` does not exist.

- [ ] **Step 3: Implement upgrade system**

Create `scripts/systems/upgrade_system.gd`:

```gdscript
extends RefCounted
class_name UpgradeSystem

var upgrades: Array[Dictionary] = []

func configure(new_upgrades: Array[Dictionary]) -> void:
	upgrades = new_upgrades.duplicate(true)

func get_choices(runtime_state: Dictionary, count: int = 3, seed_value: int = 0) -> Array[Dictionary]:
	var available := _get_available_upgrades(runtime_state)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()

	var choices: Array[Dictionary] = []
	while not available.is_empty() and choices.size() < count:
		var index := rng.randi_range(0, available.size() - 1)
		choices.append(available[index])
		available.remove_at(index)
	return choices

func apply_upgrade(runtime_state: Dictionary, upgrade: Dictionary) -> void:
	if not runtime_state.has("upgrade_stacks"):
		runtime_state["upgrade_stacks"] = {}

	var id: String = upgrade["id"]
	var stacks: Dictionary = runtime_state["upgrade_stacks"]
	stacks[id] = int(stacks.get(id, 0)) + 1

	if upgrade.get("kind", "") == "weapon_level":
		var weapon_id: String = upgrade.get("weapon_id", "")
		var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
		owned_weapons[weapon_id] = int(owned_weapons.get(weapon_id, 1)) + 1
		runtime_state["owned_weapons"] = owned_weapons

func _get_available_upgrades(runtime_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})
	var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})

	for upgrade in upgrades:
		var id: String = upgrade["id"]
		var current_stacks := int(stacks.get(id, 0))
		var max_stacks := int(upgrade.get("max_stacks", 1))
		if current_stacks >= max_stacks:
			continue

		if upgrade.get("kind", "") == "weapon_level":
			var weapon_id: String = upgrade.get("weapon_id", "")
			if not owned_weapons.has(weapon_id):
				continue

		result.append(upgrade)

	return result
```

- [ ] **Step 4: Run tests**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL only for missing `test_weapon_system.gd`.

- [ ] **Step 5: Commit upgrade system**

```powershell
git add scripts/systems/upgrade_system.gd tests/test_upgrade_system.gd
git commit -m "feat: add upgrade choice system"
```

## Task 5: Weapon System

**Files:**
- Create: `scripts/systems/weapon_system.gd`
- Create: `tests/test_weapon_system.gd`

- [ ] **Step 1: Write the failing weapon system test**

Create `tests/test_weapon_system.gd`:

```gdscript
extends RefCounted

const GameDatabase := preload("res://scripts/data/game_database.gd")
const WeaponSystem := preload("res://scripts/systems/weapon_system.gd")

func run(runner) -> void:
	var db := GameDatabase.new()
	runner.assert_true(db.load_all(), "database should load before weapon tests")

	var system := WeaponSystem.new()
	system.add_weapon(db.get_weapon("flying_sword"))

	runner.assert_eq(system.get_weapon_level("flying_sword"), 1, "new weapon starts at level 1")
	runner.assert_eq(system.tick(0.4).size(), 0, "weapon should not fire before cooldown")

	var fire_events := system.tick(0.6)
	runner.assert_eq(fire_events.size(), 1, "weapon should fire after cooldown")
	runner.assert_eq(fire_events[0]["weapon_id"], "flying_sword", "fire event weapon id")
	runner.assert_eq(fire_events[0]["damage"], 12, "fire event base damage")

	system.level_weapon("flying_sword")
	runner.assert_eq(system.get_weapon_level("flying_sword"), 2, "weapon level increments")
	runner.assert_eq(system.get_weapon_damage("flying_sword"), 16, "level 2 damage modifier applies")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because `weapon_system.gd` does not exist.

- [ ] **Step 3: Implement weapon system**

Create `scripts/systems/weapon_system.gd`:

```gdscript
extends Node
class_name WeaponSystem

var weapons: Dictionary = {}

func add_weapon(definition: Dictionary) -> void:
	var id: String = definition["id"]
	weapons[id] = {
		"definition": definition.duplicate(true),
		"level": 1,
		"cooldown_remaining": float(definition.get("cooldown", 1.0))
	}

func has_weapon(id: String) -> bool:
	return weapons.has(id)

func get_weapon_level(id: String) -> int:
	if not weapons.has(id):
		return 0
	return int(weapons[id]["level"])

func level_weapon(id: String) -> void:
	if not weapons.has(id):
		return
	var state: Dictionary = weapons[id]
	var definition: Dictionary = state["definition"]
	var max_level := int(definition.get("max_level", 1))
	state["level"] = min(max_level, int(state["level"]) + 1)

func tick(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for id in weapons.keys():
		var state: Dictionary = weapons[id]
		state["cooldown_remaining"] = float(state["cooldown_remaining"]) - delta
		if float(state["cooldown_remaining"]) <= 0.0:
			events.append(_build_fire_event(id, state))
			state["cooldown_remaining"] += get_weapon_cooldown(id)
	return events

func get_weapon_damage(id: String) -> int:
	var value := int(_get_base_definition_value(id, "base_damage", 1))
	for modifier in _get_active_level_modifiers(id):
		if modifier.has("base_damage"):
			value = int(modifier["base_damage"])
	return value

func get_weapon_cooldown(id: String) -> float:
	var value := float(_get_base_definition_value(id, "cooldown", 1.0))
	for modifier in _get_active_level_modifiers(id):
		if modifier.has("cooldown"):
			value = float(modifier["cooldown"])
	return max(0.05, value)

func _build_fire_event(id: String, state: Dictionary) -> Dictionary:
	var definition: Dictionary = state["definition"]
	return {
		"weapon_id": id,
		"damage": get_weapon_damage(id),
		"range": int(definition.get("range", 320)),
		"projectile_speed": int(definition.get("projectile_speed", 480)),
		"projectile_count": _get_projectile_count(id)
	}

func _get_projectile_count(id: String) -> int:
	var value := int(_get_base_definition_value(id, "projectile_count", 1))
	for modifier in _get_active_level_modifiers(id):
		if modifier.has("projectile_count"):
			value = int(modifier["projectile_count"])
	return value

func _get_base_definition_value(id: String, key: String, fallback: Variant) -> Variant:
	if not weapons.has(id):
		return fallback
	return weapons[id]["definition"].get(key, fallback)

func _get_active_level_modifiers(id: String) -> Array:
	if not weapons.has(id):
		return []

	var state: Dictionary = weapons[id]
	var current_level := int(state["level"])
	var definition: Dictionary = state["definition"]
	var result := []
	for modifier in definition.get("level_modifiers", []):
		if int(modifier.get("level", 1)) <= current_level:
			result.append(modifier)
	return result
```

- [ ] **Step 4: Run tests**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: PASS with `All tests passed.`

- [ ] **Step 5: Commit weapon system**

```powershell
git add scripts/systems/weapon_system.gd tests/test_weapon_system.gd
git commit -m "feat: add weapon cooldown system"
```

## Task 6: Player, Enemy, Projectile, And Minimal Game Scene

**Files:**
- Create: `scripts/player/player_controller.gd`
- Create: `scripts/enemies/enemy_agent.gd`
- Create: `scripts/weapons/projectile.gd`
- Create: `scripts/systems/enemy_director.gd`
- Create: `scripts/systems/experience_system.gd`
- Create: `scripts/core/game_loop.gd`
- Create: `scenes/player/Player.tscn`
- Create: `scenes/enemies/BasicDemon.tscn`
- Create: `scenes/weapons/Projectile.tscn`
- Create: `scenes/game/Game.tscn`
- Create: `scenes/boot/Boot.tscn`

- [ ] **Step 1: Add player controller**

Create `scripts/player/player_controller.gd`:

```gdscript
extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 260.0

@onready var health: HealthComponent = $HealthComponent

func _ready() -> void:
	add_to_group(GameConstants.PLAYER_GROUP)
	health.configure(100)

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	velocity = input_vector * move_speed
	move_and_slide()
```

- [ ] **Step 2: Add enemy agent**

Create `scripts/enemies/enemy_agent.gd`:

```gdscript
extends CharacterBody2D
class_name EnemyAgent

@export var move_speed: float = 110.0
@export var contact_damage: int = 8
@export var experience_value: int = 1

@onready var health: HealthComponent = $HealthComponent

var target: Node2D

func configure(definition: Dictionary, new_target: Node2D) -> void:
	target = new_target
	move_speed = float(definition.get("move_speed", move_speed))
	contact_damage = int(definition.get("contact_damage", contact_damage))
	experience_value = int(definition.get("experience_value", experience_value))
	health.configure(int(definition.get("max_health", 24)))

func _ready() -> void:
	add_to_group(GameConstants.ENEMY_GROUP)
	health.died.connect(queue_free)

func _physics_process(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(target.global_position) * move_speed
	move_and_slide()
```

- [ ] **Step 3: Add projectile behavior**

Create `scripts/weapons/projectile.gd`:

```gdscript
extends Area2D
class_name Projectile

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var remaining_lifetime: float = 1.5

func configure(direction: Vector2, speed: float, new_damage: int) -> void:
	velocity = direction.normalized() * speed
	damage = new_damage

func _ready() -> void:
	add_to_group(GameConstants.PROJECTILE_GROUP)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	_damage_if_possible(parent)

func _on_body_entered(body: Node) -> void:
	_damage_if_possible(body)

func _damage_if_possible(target: Node) -> void:
	if target == null or not target.is_in_group(GameConstants.ENEMY_GROUP):
		return
	var health := target.get_node_or_null("HealthComponent")
	if health != null and health.has_method("take_damage"):
		health.take_damage(damage)
		queue_free()
```

- [ ] **Step 4: Add enemy director**

Create `scripts/systems/enemy_director.gd`:

```gdscript
extends Node
class_name EnemyDirector

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 520.0

var database: GameDatabase
var player: Node2D
var elapsed: float = 0.0
var wave_events: Array[Dictionary] = []
var triggered_events: Dictionary = {}

func configure(new_database: GameDatabase, new_player: Node2D) -> void:
	database = new_database
	player = new_player
	wave_events = database.get_wave_events()

func _process(delta: float) -> void:
	if database == null or player == null or enemy_scene == null:
		return

	elapsed += delta
	for event in wave_events:
		var event_time := float(event.get("time", 0.0))
		if elapsed >= event_time and not triggered_events.has(event_time):
			triggered_events[event_time] = true
			_spawn_wave(event)

func _spawn_wave(event: Dictionary) -> void:
	var enemy_id: String = event.get("enemy_id", "basic_demon")
	var definition := database.get_enemy(enemy_id)
	var count := int(event.get("spawn_count", 1))
	for index in range(count):
		var enemy: EnemyAgent = enemy_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = player.global_position + Vector2.RIGHT.rotated(TAU * float(index) / max(1, count)) * spawn_radius
		enemy.configure(definition, player)
```

- [ ] **Step 5: Add experience system**

Create `scripts/systems/experience_system.gd`:

```gdscript
extends Node
class_name ExperienceSystem

signal level_up(new_level: int)
signal experience_changed(current: int, required: int)

var level: int = 1
var current_experience: int = 0

func get_required_experience() -> int:
	return 5 + (level - 1) * 3

func add_experience(amount: int) -> void:
	current_experience += max(0, amount)
	while current_experience >= get_required_experience():
		current_experience -= get_required_experience()
		level += 1
		level_up.emit(level)
	experience_changed.emit(current_experience, get_required_experience())
```

- [ ] **Step 6: Add game loop**

Create `scripts/core/game_loop.gd`:

```gdscript
extends Node2D
class_name GameLoop

@export var projectile_scene: PackedScene

@onready var player: PlayerController = $Player
@onready var enemy_director: EnemyDirector = $EnemyDirector
@onready var experience_system: ExperienceSystem = $ExperienceSystem
@onready var weapon_system: WeaponSystem = $WeaponSystem

var database := GameDatabase.new()
var runtime_state := {
	"owned_weapons": { "flying_sword": 1 },
	"upgrade_stacks": {}
}

func _ready() -> void:
	var loaded := database.load_all()
	assert(loaded, "Game database failed to load: %s" % str(database.errors))

	weapon_system.add_weapon(database.get_weapon("flying_sword"))
	enemy_director.configure(database, player)

func _process(delta: float) -> void:
	var fire_events := weapon_system.tick(delta)
	for event in fire_events:
		_spawn_projectiles(event)

func _spawn_projectiles(event: Dictionary) -> void:
	var enemies := get_tree().get_nodes_in_group(GameConstants.ENEMY_GROUP)
	if enemies.is_empty() or projectile_scene == null:
		return

	var target: Node2D = enemies[0]
	var direction := player.global_position.direction_to(target.global_position)
	var count := int(event.get("projectile_count", 1))
	for index in range(count):
		var projectile: Projectile = projectile_scene.instantiate()
		add_child(projectile)
		projectile.global_position = player.global_position
		var spread := deg_to_rad(8.0 * (index - (count - 1) / 2.0))
		projectile.configure(direction.rotated(spread), float(event["projectile_speed"]), int(event["damage"]))
```

- [ ] **Step 7: Create minimal scenes in the Godot editor or as text scenes**

Create `scenes/player/Player.tscn`:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]

[sub_resource type="CircleShape2D" id="CircleShape2D_player"]
radius = 18.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_player")
```

Create `scenes/enemies/BasicDemon.tscn`:

```ini
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/enemies/enemy_agent.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]

[sub_resource type="CircleShape2D" id="CircleShape2D_enemy"]
radius = 16.0

[node name="BasicDemon" type="CharacterBody2D"]
script = ExtResource("1")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_enemy")
```

Create `scenes/weapons/Projectile.tscn`:

```ini
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/weapons/projectile.gd" id="1"]

[sub_resource type="CircleShape2D" id="CircleShape2D_projectile"]
radius = 8.0

[node name="Projectile" type="Area2D"]
script = ExtResource("1")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_projectile")
```

Create `scenes/game/Game.tscn`:

```ini
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/core/game_loop.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/player/Player.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/enemies/BasicDemon.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/weapons/Projectile.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/systems/enemy_director.gd" id="5"]
[ext_resource type="Script" path="res://scripts/systems/experience_system.gd" id="6"]
[ext_resource type="Script" path="res://scripts/systems/weapon_system.gd" id="7"]

[node name="Game" type="Node2D"]
script = ExtResource("1")
projectile_scene = ExtResource("4")

[node name="Player" parent="." instance=ExtResource("2")]
position = Vector2(360, 640)

[node name="EnemyDirector" type="Node" parent="."]
script = ExtResource("5")
enemy_scene = ExtResource("3")

[node name="ExperienceSystem" type="Node" parent="."]
script = ExtResource("6")

[node name="WeaponSystem" type="Node" parent="."]
script = ExtResource("7")
```

Create `scenes/boot/Boot.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/game/Game.tscn" id="1"]

[node name="Boot" type="Node"]

[node name="Game" parent="." instance=ExtResource("1")]
```

- [ ] **Step 8: Run tests**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: PASS with `All tests passed.`

- [ ] **Step 9: Run the game scene smoke check**

Run:

```powershell
& $env:GODOT_BIN --headless --path . --quit-after 3
```

Expected: process exits with code 0 and no script errors.

- [ ] **Step 10: Commit playable foundation**

```powershell
git add scripts/player scripts/enemies scripts/weapons scripts/systems scripts/core/game_loop.gd scenes
git commit -m "feat: wire minimal playable run scene"
```

## Task 7: HUD And Upgrade Pause Panel

**Files:**
- Create: `scripts/ui/hud.gd`
- Create: `scripts/ui/upgrade_choice_panel.gd`
- Create: `scenes/ui/HUD.tscn`
- Create: `scenes/ui/UpgradeChoicePanel.tscn`
- Modify: `scripts/core/game_loop.gd`
- Modify: `scenes/game/Game.tscn`

- [ ] **Step 1: Add HUD script**

Create `scripts/ui/hud.gd`:

```gdscript
extends CanvasLayer
class_name HUD

@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel
@onready var experience_label: Label = $MarginContainer/VBoxContainer/ExperienceLabel

func set_run_time(seconds: float) -> void:
	var minutes := int(seconds / 60.0)
	var remainder := int(seconds) % 60
	timer_label.text = "%02d:%02d" % [minutes, remainder]

func set_level(level: int) -> void:
	level_label.text = "Lv %d" % level

func set_experience(current: int, required: int) -> void:
	experience_label.text = "EXP %d/%d" % [current, required]
```

- [ ] **Step 2: Add upgrade panel script**

Create `scripts/ui/upgrade_choice_panel.gd`:

```gdscript
extends CanvasLayer
class_name UpgradeChoicePanel

signal upgrade_selected(upgrade: Dictionary)

@onready var buttons := [
	$PanelContainer/VBoxContainer/Button1,
	$PanelContainer/VBoxContainer/Button2,
	$PanelContainer/VBoxContainer/Button3
]

var current_choices: Array[Dictionary] = []

func _ready() -> void:
	for index in buttons.size():
		buttons[index].pressed.connect(_on_button_pressed.bind(index))
	hide()

func show_choices(choices: Array[Dictionary]) -> void:
	current_choices = choices
	for index in buttons.size():
		var button: Button = buttons[index]
		if index < choices.size():
			button.text = choices[index].get("display_name", choices[index].get("id", "Upgrade"))
			button.disabled = false
		else:
			button.text = "-"
			button.disabled = true
	show()

func _on_button_pressed(index: int) -> void:
	if index >= current_choices.size():
		return
	var selected := current_choices[index]
	hide()
	upgrade_selected.emit(selected)
```

- [ ] **Step 3: Create HUD scene**

Create `scenes/ui/HUD.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="MarginContainer" type="MarginContainer" parent="."]
offset_right = 720.0
offset_bottom = 160.0

[node name="VBoxContainer" type="VBoxContainer" parent="MarginContainer"]

[node name="TimerLabel" type="Label" parent="MarginContainer/VBoxContainer"]
text = "00:00"

[node name="LevelLabel" type="Label" parent="MarginContainer/VBoxContainer"]
text = "Lv 1"

[node name="ExperienceLabel" type="Label" parent="MarginContainer/VBoxContainer"]
text = "EXP 0/5"
```

- [ ] **Step 4: Create upgrade panel scene**

Create `scenes/ui/UpgradeChoicePanel.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/upgrade_choice_panel.gd" id="1"]

[node name="UpgradeChoicePanel" type="CanvasLayer"]
script = ExtResource("1")

[node name="PanelContainer" type="PanelContainer" parent="."]
offset_left = 80.0
offset_top = 300.0
offset_right = 640.0
offset_bottom = 900.0

[node name="VBoxContainer" type="VBoxContainer" parent="PanelContainer"]

[node name="Button1" type="Button" parent="PanelContainer/VBoxContainer"]
text = "Upgrade 1"

[node name="Button2" type="Button" parent="PanelContainer/VBoxContainer"]
text = "Upgrade 2"

[node name="Button3" type="Button" parent="PanelContainer/VBoxContainer"]
text = "Upgrade 3"
```

- [ ] **Step 5: Wire HUD and upgrade panel into game loop**

Modify `scripts/core/game_loop.gd` so it contains these additional members and methods:

```gdscript
@onready var hud: HUD = $HUD
@onready var upgrade_choice_panel: UpgradeChoicePanel = $UpgradeChoicePanel

var upgrade_system := UpgradeSystem.new()
var run_time: float = 0.0
```

In `_ready`, add:

```gdscript
upgrade_system.configure(database.get_upgrades())
experience_system.level_up.connect(_on_level_up)
experience_system.experience_changed.connect(hud.set_experience)
upgrade_choice_panel.upgrade_selected.connect(_on_upgrade_selected)
hud.set_level(experience_system.level)
hud.set_experience(experience_system.current_experience, experience_system.get_required_experience())
```

In `_process`, add before weapon events:

```gdscript
run_time += delta
hud.set_run_time(run_time)
```

Add:

```gdscript
func _on_level_up(new_level: int) -> void:
	hud.set_level(new_level)
	get_tree().paused = true
	var choices := upgrade_system.get_choices(runtime_state, 3)
	upgrade_choice_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_choice_panel.show_choices(choices)

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	upgrade_system.apply_upgrade(runtime_state, upgrade)
	if upgrade.get("kind", "") == "weapon_level":
		weapon_system.level_weapon(upgrade.get("weapon_id", ""))
	get_tree().paused = false
```

- [ ] **Step 6: Modify `scenes/game/Game.tscn` to instance HUD and upgrade panel**

Add these external resources:

```ini
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="8"]
[ext_resource type="PackedScene" path="res://scenes/ui/UpgradeChoicePanel.tscn" id="9"]
```

Add these nodes under `Game`:

```ini
[node name="HUD" parent="." instance=ExtResource("8")]

[node name="UpgradeChoicePanel" parent="." instance=ExtResource("9")]
```

- [ ] **Step 7: Run tests and scene smoke check**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
& $env:GODOT_BIN --headless --path . --quit-after 3
```

Expected: tests pass and game scene exits with code 0.

- [ ] **Step 8: Commit HUD and upgrade UI**

```powershell
git add scripts/ui scenes/ui scripts/core/game_loop.gd scenes/game/Game.tscn
git commit -m "feat: add run HUD and upgrade choices"
```

## Task 8: First Asset Prompt Manifest

**Files:**
- Create: `docs/art/asset-prompt-manifest.md`
- Create: `art/characters/.gitkeep`
- Create: `art/enemies/.gitkeep`
- Create: `art/weapons/.gitkeep`
- Create: `art/effects/.gitkeep`
- Create: `art/icons/.gitkeep`
- Create: `art/environment/.gitkeep`
- Create: `art/ui/.gitkeep`

- [ ] **Step 1: Create art folders**

Create empty `.gitkeep` files in:

```text
art/characters/.gitkeep
art/enemies/.gitkeep
art/weapons/.gitkeep
art/effects/.gitkeep
art/icons/.gitkeep
art/environment/.gitkeep
art/ui/.gitkeep
```

- [ ] **Step 2: Create first prompt manifest**

Create `docs/art/asset-prompt-manifest.md`:

```markdown
# Asset Prompt Manifest

## Shared Cutout Constraints

Use case: stylized-concept
Asset type: mobile 2D game pixel art asset
Style/medium: 3/4 top-down pixel art, crisp silhouette, readable at small mobile size
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background
Constraints: no shadows, no cast shadow, no contact shadow, no gradients, no texture in the background, no floor plane, no reflection, no watermark, no text, generous padding, subject fully separated from background, do not use #00ff00 anywhere in the subject
Avoid: blur, painterly smearing, realistic photo rendering, tiny unreadable details, cropped subject

## First Batch Prompts

### Player: Artificer Cultivator Front Walk Frame

Create a 3/4 top-down pixel art sprite of an eastern fantasy artificer cultivator in talisman robes with subtle brass mechanism details, front-facing walk pose, compact mobile-game proportions, clean readable silhouette.

### Player: Artificer Cultivator Back Walk Frame

Create a 3/4 top-down pixel art sprite of the same eastern fantasy artificer cultivator from the back, talisman robe silhouette and small brass mechanism details visible, compact mobile-game proportions, clean readable silhouette.

### Enemy: Small Demon Move Frame

Create a 3/4 top-down pixel art sprite of a small eastern fantasy demon minion, hunched body, horned silhouette, dark red and charcoal colors, simple readable shape for survivor-game swarms.

### Weapon: Flying Sword Projectile

Create a 3/4 top-down pixel art sprite of a talisman-guided flying sword projectile, silver blade with warm gold talisman strip, crisp outline, readable at small size.
```

- [ ] **Step 3: Commit asset planning**

```powershell
git add docs/art art
git commit -m "docs: add first asset prompt manifest"
```

## Final Verification

- [ ] **Step 1: Run all tests**

Run:

```powershell
& $env:GODOT_BIN --headless --path . -s res://tests/run_all_tests.gd
```

Expected: PASS with `All tests passed.`

- [ ] **Step 2: Run smoke scene**

Run:

```powershell
& $env:GODOT_BIN --headless --path . --quit-after 3
```

Expected: exits with code 0 and no script errors.

- [ ] **Step 3: Inspect git status**

Run:

```powershell
git status --short --branch
```

Expected: clean working tree on `main`.

## Spec Coverage Review

Covered by this plan:

- Godot 4 + GDScript project foundation.
- Data-driven starter content.
- First weapon, first enemy, and first wave.
- Upgrade choice generation and application.
- Player movement foundation.
- Enemy chase behavior.
- Minimal run scene.
- Headless tests.
- Art prompt manifest for `gpt-image-2` green-screen asset generation.

Covered by later plans:

- All four weapons and weapon evolutions.
- Full enemy roster and boss.
- Equipment upgrade UI and save system.
- Final generated image asset production and chroma-key removal.
- Android export.
- Performance pass for large enemy counts.
