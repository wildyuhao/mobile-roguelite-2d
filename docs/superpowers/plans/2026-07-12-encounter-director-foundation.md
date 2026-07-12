# Encounter Director Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic encounter selection, pressure budgeting, seven formation templates, capped spawn queues, and a 15-minute simulator while preserving fixed story waves.

**Architecture:** `GameDatabase` owns encounter and formation content. Three pure systems own selection (`EncounterBag`), pressure rules (`PressureBudget`), and positions (`FormationPlanner`). `EnemyDirector` remains the scene adapter: fixed waves and director cards both become queued spawn requests, while no pure system instantiates nodes.

**Tech Stack:** Godot 4.7, GDScript, JSON content data, existing headless test runner, Git.

## Global Constraints

- Fixed elite and boss timeline events remain deterministic; the encounter director only fills ordinary pressure.
- Encounter draws begin at 45 seconds and recur at deterministic 45-60 second intervals.
- Effective pressure adjustment is clamped to `-15%..+15%` around the time baseline.
- A heavy player hit suppresses positive pressure adjustment for 8 seconds.
- Ranged units may not exceed 35% of the active-plus-planned enemy population.
- Simultaneous strong-control units may not exceed 2.
- The first chapter keeps `spawn_radius = 360` for current mobile visibility; wider off-screen spawning remains a later device-tuning pass.
- A surround formation leaves a visible escape gap of at least 60 degrees.
- Active enemies are capped at 140 and no more than 6 queued enemies instantiate in one frame.
- No encounter or enemy signature may be selected three draws in a row.
- All selection and simulation behavior is deterministic for a supplied seed.
- Object pooling is a separate follow-up plan because it requires reusable enemy lifecycle and signal-reset contracts.
- Every production change follows red-green-refactor and ends with the complete Godot suite.

---

## File Map

- Create `data/encounters/formations.json`: seven data-driven formation templates.
- Create `data/encounters/first_chapter.json`: seven first-chapter encounter cards.
- Modify `data/enemies/*.json`: add `role` and `pressure_cost` metadata.
- Modify `scripts/data/game_database.gd`: load and validate encounter references.
- Create `scripts/systems/encounter_bag.gd`: seeded weighted draw with cooldown and anti-triple rules.
- Create `scripts/systems/pressure_budget.gd`: time budget, recovery suppression, ranged/control caps.
- Create `scripts/systems/formation_planner.gd`: deterministic slot generation for seven patterns.
- Modify `scripts/systems/enemy_director.gd`: schedule cards and enforce queue/active caps.
- Modify `scripts/core/game_loop.gd`: notify the director after a heavy player hit.
- Create `scripts/systems/encounter_simulator.gd`: no-render deterministic 15-minute simulation.
- Create `tools/simulate_encounters.gd`: command-line report entrypoint.
- Add focused tests and register them in `tests/run_all_tests.gd`.

---

### Task 1: Encounter Content Schema and Validation

**Files:**
- Create: `data/encounters/formations.json`
- Create: `data/encounters/first_chapter.json`
- Modify: `data/enemies/basic_demon.json`
- Modify: `data/enemies/charging_demon.json`
- Modify: `data/enemies/ranged_demon.json`
- Modify: `data/enemies/elite_guardian.json`
- Modify: `data/enemies/seal_boss.json`
- Modify: `scripts/data/game_database.gd`
- Modify: `tests/test_game_database.gd`

**Interfaces:**
- Produces: `get_encounters() -> Array[Dictionary]`, `get_formations() -> Dictionary`, and validated enemy/formation references.

- [ ] **Step 1: Add failing database assertions**

Append to `tests/test_game_database.gd::run`:

```gdscript
	runner.assert_true(db.has_method("get_encounters"), "database should expose encounter cards")
	runner.assert_true(db.has_method("get_formations"), "database should expose formation templates")
	if db.has_method("get_encounters") and db.has_method("get_formations"):
		var encounters: Array[Dictionary] = db.get_encounters()
		var formations: Dictionary = db.get_formations()
		runner.assert_eq(encounters.size(), 7, "first chapter should define seven encounter cards")
		runner.assert_eq(formations.size(), 7, "first chapter should define seven formations")
		for encounter in encounters:
			runner.assert_true(formations.has(String(encounter.get("formation_id", ""))), "encounter formation should resolve")
			for group in encounter.get("groups", []):
				runner.assert_true(db.has_enemy(String(group.get("enemy_id", ""))), "encounter enemy should resolve")
	for enemy_id in db.get_enemies().keys():
		var enemy: Dictionary = db.get_enemy(enemy_id)
		runner.assert_true(String(enemy.get("role", "")) != "", "%s should declare a role" % enemy_id)
		runner.assert_true(int(enemy.get("pressure_cost", 0)) > 0, "%s should declare pressure cost" % enemy_id)
```

- [ ] **Step 2: Run the suite and verify the missing-method failure**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because encounter getters and content do not exist.

- [ ] **Step 3: Add seven formation templates**

Create `data/encounters/formations.json`:

```json
[
  { "id": "surround_gap", "pattern": "ring_gap", "gap_degrees": 70.0, "radius_scale": 1.0 },
  { "id": "wedge_charge", "pattern": "wedge", "row_spacing": 62.0, "column_spacing": 58.0, "radius_scale": 1.0 },
  { "id": "turret_escort", "pattern": "escort", "front_ratio": 0.72, "rear_offset": 92.0, "radius_scale": 1.0 },
  { "id": "elite_lead", "pattern": "leader_flanks", "flank_angle_degrees": 36.0, "depth_spacing": 64.0, "radius_scale": 1.0 },
  { "id": "seal_contest", "pattern": "dual_ring", "inner_radius_scale": 0.72, "radius_scale": 1.0 },
  { "id": "chest_ambush", "pattern": "pincer", "side_angle_degrees": 76.0, "depth_spacing": 54.0, "radius_scale": 0.96 },
  { "id": "boss_vanguard", "pattern": "corridor", "lane_spacing": 68.0, "depth_spacing": 58.0, "radius_scale": 1.0 }
]
```

- [ ] **Step 4: Add seven encounter cards**

Create `data/encounters/first_chapter.json`:

```json
[
  { "id": "four_side_surround", "weight": 6, "min_time": 45.0, "max_time": 420.0, "cooldown_draws": 1, "pressure_cost": 10, "formation_id": "surround_gap", "groups": [{ "enemy_id": "basic_demon", "count": 10 }] },
  { "id": "wedge_charge", "weight": 5, "min_time": 60.0, "max_time": 420.0, "cooldown_draws": 2, "pressure_cost": 16, "formation_id": "wedge_charge", "groups": [{ "enemy_id": "charging_demon", "count": 4 }, { "enemy_id": "basic_demon", "count": 4 }] },
  { "id": "turret_escort", "weight": 5, "min_time": 75.0, "max_time": 420.0, "cooldown_draws": 2, "pressure_cost": 14, "formation_id": "turret_escort", "groups": [{ "enemy_id": "basic_demon", "count": 8 }, { "enemy_id": "ranged_demon", "count": 2 }] },
  { "id": "elite_lead", "weight": 3, "min_time": 120.0, "max_time": 420.0, "cooldown_draws": 3, "pressure_cost": 16, "formation_id": "elite_lead", "groups": [{ "enemy_id": "elite_guardian", "count": 1 }, { "enemy_id": "basic_demon", "count": 8 }] },
  { "id": "seal_contest", "weight": 4, "min_time": 150.0, "max_time": 420.0, "cooldown_draws": 2, "pressure_cost": 14, "formation_id": "seal_contest", "groups": [{ "enemy_id": "basic_demon", "count": 8 }, { "enemy_id": "charging_demon", "count": 2 }] },
  { "id": "chest_ambush", "weight": 4, "min_time": 180.0, "max_time": 420.0, "cooldown_draws": 2, "pressure_cost": 15, "formation_id": "chest_ambush", "groups": [{ "enemy_id": "basic_demon", "count": 6 }, { "enemy_id": "ranged_demon", "count": 3 }] },
  { "id": "boss_vanguard", "weight": 2, "min_time": 300.0, "max_time": 450.0, "cooldown_draws": 4, "pressure_cost": 20, "formation_id": "boss_vanguard", "groups": [{ "enemy_id": "elite_guardian", "count": 1 }, { "enemy_id": "charging_demon", "count": 2 }, { "enemy_id": "basic_demon", "count": 6 }] }
]
```

- [ ] **Step 5: Add enemy role metadata**

Add these exact pairs to the five enemy JSON objects:

```text
basic_demon:      "role": "swarm",   "pressure_cost": 1
charging_demon:   "role": "charger", "pressure_cost": 3
ranged_demon:     "role": "ranged",  "pressure_cost": 3
elite_guardian:   "role": "elite",   "pressure_cost": 8
seal_boss:        "role": "boss",    "pressure_cost": 30
```

- [ ] **Step 6: Load and validate encounter content**

In `scripts/data/game_database.gd`, add fields and load calls:

```gdscript
var encounters: Array[Dictionary] = []
var formations: Dictionary = {}

# In load_all, after enemies load:
formations = _array_to_id_map(_load_json_array("res://data/encounters/formations.json"), "formation")
encounters = _load_json_array("res://data/encounters/first_chapter.json")
_validate_encounters()

func get_encounters() -> Array[Dictionary]:
	return encounters

func get_formations() -> Dictionary:
	return formations

func _array_to_id_map(items: Array[Dictionary], label: String) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		var id := String(item.get("id", ""))
		if id == "":
			errors.append("%s definition has no id" % label)
		elif result.has(id):
			errors.append("Duplicate %s id: %s" % [label, id])
		else:
			result[id] = item
	return result

func _validate_encounters() -> void:
	var encounter_ids: Dictionary = {}
	for encounter in encounters:
		var encounter_id := String(encounter.get("id", ""))
		if encounter_id == "" or encounter_ids.has(encounter_id):
			errors.append("Invalid or duplicate encounter id: %s" % encounter_id)
		encounter_ids[encounter_id] = true
		var formation_id := String(encounter.get("formation_id", ""))
		if not formations.has(formation_id):
			errors.append("Encounter %s references missing formation %s" % [encounter_id, formation_id])
		if int(encounter.get("weight", 0)) <= 0 or int(encounter.get("pressure_cost", 0)) <= 0:
			errors.append("Encounter %s has invalid weight or pressure" % encounter_id)
		var groups: Array = encounter.get("groups", [])
		if groups.is_empty():
			errors.append("Encounter %s has no groups" % encounter_id)
		for group in groups:
			var enemy_id := String(group.get("enemy_id", ""))
			if not enemies.has(enemy_id) or int(group.get("count", 0)) <= 0:
				errors.append("Encounter %s has invalid enemy group %s" % [encounter_id, enemy_id])
```

- [ ] **Step 7: Run the suite and commit**

Expected: `All tests passed.`

```powershell
git add data/encounters data/enemies scripts/data/game_database.gd tests/test_game_database.gd
git commit -m "feat: add validated encounter content"
```

---

### Task 2: Seeded Encounter Random Bag

**Files:**
- Create: `scripts/systems/encounter_bag.gd`
- Create: `tests/test_encounter_bag.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `configure(cards, seed)`, `draw(elapsed, budget) -> Dictionary`, and anti-triple history for card IDs and enemy signatures.

- [ ] **Step 1: Write the failing bag test**

Create `tests/test_encounter_bag.gd` with two identical seeded bags. Draw 30 times from three cards, assert identical IDs, no three card IDs in a row, no three enemy signatures in a row, and no card above budget or outside its time window.

```gdscript
extends RefCounted

const CARDS: Array[Dictionary] = [
	{"id": "a", "weight": 5, "min_time": 0.0, "max_time": 999.0, "cooldown_draws": 0, "pressure_cost": 4, "groups": [{"enemy_id": "basic", "count": 4}]},
	{"id": "b", "weight": 3, "min_time": 0.0, "max_time": 999.0, "cooldown_draws": 0, "pressure_cost": 5, "groups": [{"enemy_id": "charge", "count": 1}]},
	{"id": "c", "weight": 2, "min_time": 10.0, "max_time": 999.0, "cooldown_draws": 1, "pressure_cost": 8, "groups": [{"enemy_id": "ranged", "count": 2}]},
]

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/encounter_bag.gd"):
		runner.assert_true(false, "encounter bag should exist")
		return
	var script = load("res://scripts/systems/encounter_bag.gd")
	var first = script.new()
	var second = script.new()
	first.configure(CARDS, 20260712)
	second.configure(CARDS, 20260712)
	var ids: Array[String] = []
	var signatures: Array[String] = []
	for index in range(30):
		var elapsed := 20.0 + index
		var a: Dictionary = first.draw(elapsed, 8)
		var b: Dictionary = second.draw(elapsed, 8)
		runner.assert_eq(a.get("id", ""), b.get("id", ""), "same seed should produce same draw")
		runner.assert_true(int(a.get("pressure_cost", 999)) <= 8, "draw should respect budget")
		ids.append(String(a.get("id", "")))
		signatures.append(first.enemy_signature(a))
		if ids.size() >= 3:
			runner.assert_true(not (ids[-1] == ids[-2] and ids[-2] == ids[-3]), "card should not repeat three times")
			runner.assert_true(not (signatures[-1] == signatures[-2] and signatures[-2] == signatures[-3]), "enemy signature should not repeat three times")
	var unavailable: Dictionary = first.draw(2.0, 3)
	runner.assert_true(unavailable.is_empty(), "no eligible card should return an empty draw")
```

Register after `test_enemy_director.gd`.

- [ ] **Step 2: Run and verify RED**

Expected: FAIL because `encounter_bag.gd` does not exist.

- [ ] **Step 3: Implement `EncounterBag`**

Create `scripts/systems/encounter_bag.gd`:

```gdscript
extends RefCounted
class_name EncounterBag

var cards: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var draw_index: int = 0
var last_draw_by_id: Dictionary = {}
var recent_ids: Array[String] = []
var recent_signatures: Array[String] = []

func configure(new_cards: Array[Dictionary], seed: int) -> void:
	cards = new_cards.duplicate(true)
	rng.seed = seed
	draw_index = 0
	last_draw_by_id.clear()
	recent_ids.clear()
	recent_signatures.clear()

func draw(elapsed: float, budget: int) -> Dictionary:
	var eligible: Array[Dictionary] = []
	var total_weight := 0
	for card in cards:
		if elapsed < float(card.get("min_time", 0.0)) or elapsed > float(card.get("max_time", INF)):
			continue
		if int(card.get("pressure_cost", 0)) > budget:
			continue
		var id := String(card.get("id", ""))
		var cooldown := int(card.get("cooldown_draws", 0))
		if last_draw_by_id.has(id) and draw_index - int(last_draw_by_id[id]) <= cooldown:
			continue
		var signature := enemy_signature(card)
		if _would_repeat_three(recent_ids, id) or _would_repeat_three(recent_signatures, signature):
			continue
		eligible.append(card)
		total_weight += max(1, int(card.get("weight", 1)))
	if eligible.is_empty() or total_weight <= 0:
		return {}
	var ticket := rng.randi_range(1, total_weight)
	var selected: Dictionary = eligible[0]
	for card in eligible:
		ticket -= max(1, int(card.get("weight", 1)))
		if ticket <= 0:
			selected = card
			break
	var selected_id := String(selected.get("id", ""))
	var signature := enemy_signature(selected)
	draw_index += 1
	last_draw_by_id[selected_id] = draw_index
	_push_recent(recent_ids, selected_id)
	_push_recent(recent_signatures, signature)
	return selected.duplicate(true)

func enemy_signature(card: Dictionary) -> String:
	var ids: Array[String] = []
	for group in card.get("groups", []):
		ids.append(String(group.get("enemy_id", "")))
	ids.sort()
	return "+".join(ids)

func _would_repeat_three(history: Array[String], value: String) -> bool:
	return history.size() >= 2 and history[-1] == value and history[-2] == value

func _push_recent(history: Array[String], value: String) -> void:
	history.append(value)
	while history.size() > 2:
		history.pop_front()
```

- [ ] **Step 4: Run full suite and commit**

```powershell
git add scripts/systems/encounter_bag.gd tests/test_encounter_bag.gd tests/run_all_tests.gd
git commit -m "feat: add deterministic encounter bag"
```

---

### Task 3: Pressure Budget and Role Caps

**Files:**
- Create: `scripts/systems/pressure_budget.gd`
- Create: `tests/test_pressure_budget.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `get_budget(elapsed)`, `set_performance_factor(value)`, `notify_heavy_damage()`, `tick(delta)`, and `can_schedule(card, enemy_definitions, active_counts, active_total, max_active)`.

- [ ] **Step 1: Write failing pressure tests**

Create `tests/test_pressure_budget.gd`:

```gdscript
extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/pressure_budget.gd"):
		runner.assert_true(false, "pressure budget should exist")
		return
	var script = load("res://scripts/systems/pressure_budget.gd")
	var budget = script.new()
	runner.assert_eq(budget.get_budget(0.0), 14, "opening budget should be fourteen")
	runner.assert_eq(budget.get_budget(120.0), 20, "budget should rise by three per minute")
	budget.set_performance_factor(1.0)
	runner.assert_eq(budget.get_budget(120.0), 23, "positive adjustment should cap at fifteen percent")
	budget.notify_heavy_damage()
	runner.assert_eq(budget.get_budget(120.0), 20, "recovery should suppress positive adjustment")
	budget.tick(8.0)
	runner.assert_eq(budget.get_budget(120.0), 23, "adjustment should resume after recovery")
	var enemies := {
		"basic": {"role": "swarm"},
		"ranged": {"role": "ranged"},
		"control": {"role": "control"},
	}
	var ranged_card := {"groups": [{"enemy_id": "ranged", "count": 4}]}
	runner.assert_true(not budget.can_schedule(ranged_card, enemies, {"ranged": 2}, 8, 140), "ranged ratio should stay at or below thirty-five percent")
	var control_card := {"groups": [{"enemy_id": "control", "count": 1}]}
	runner.assert_true(not budget.can_schedule(control_card, enemies, {"control": 2}, 10, 140), "control count should stay at two")
	var swarm_card := {"groups": [{"enemy_id": "basic", "count": 6}]}
	runner.assert_true(not budget.can_schedule(swarm_card, enemies, {}, 138, 140), "active cap should reject oversized encounters")
```

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement `PressureBudget`**

```gdscript
extends RefCounted
class_name PressureBudget

const OPENING_BUDGET := 14
const BUDGET_PER_MINUTE := 3
const MAX_BUDGET := 32
const MAX_ADJUSTMENT := 0.15
const HEAVY_DAMAGE_RECOVERY := 8.0
const MAX_RANGED_RATIO := 0.35
const MAX_CONTROL := 2

var performance_factor: float = 0.0
var recovery_remaining: float = 0.0

func set_performance_factor(value: float) -> void:
	performance_factor = clampf(value, -1.0, 1.0)

func notify_heavy_damage() -> void:
	recovery_remaining = HEAVY_DAMAGE_RECOVERY

func tick(delta: float) -> void:
	recovery_remaining = maxf(0.0, recovery_remaining - maxf(0.0, delta))

func get_budget(elapsed: float) -> int:
	var minute_steps := int(floor(maxf(0.0, elapsed) / 60.0))
	var baseline := mini(MAX_BUDGET, OPENING_BUDGET + minute_steps * BUDGET_PER_MINUTE)
	var factor := minf(0.0, performance_factor) if recovery_remaining > 0.0 else performance_factor
	return maxi(1, int(round(baseline * (1.0 + factor * MAX_ADJUSTMENT))))

func can_schedule(card: Dictionary, enemy_definitions: Dictionary, active_counts: Dictionary, active_total: int, max_active: int) -> bool:
	var planned_total := 0
	var planned_ranged := 0
	var planned_control := 0
	for group in card.get("groups", []):
		var count := int(group.get("count", 0))
		var definition: Dictionary = enemy_definitions.get(String(group.get("enemy_id", "")), {})
		var role := String(definition.get("role", "swarm"))
		planned_total += count
		if role == "ranged":
			planned_ranged += count
		elif role == "control":
			planned_control += count
	if active_total + planned_total > max_active:
		return false
	var combined_total := active_total + planned_total
	var combined_ranged := int(active_counts.get("ranged", 0)) + planned_ranged
	if combined_total > 0 and float(combined_ranged) / float(combined_total) > MAX_RANGED_RATIO:
		return false
	return int(active_counts.get("control", 0)) + planned_control <= MAX_CONTROL
```

- [ ] **Step 4: Run full suite and commit**

```powershell
git add scripts/systems/pressure_budget.gd tests/test_pressure_budget.gd tests/run_all_tests.gd
git commit -m "feat: add encounter pressure budget"
```

---

### Task 4: Seven Deterministic Formation Patterns

**Files:**
- Create: `scripts/systems/formation_planner.gd`
- Create: `tests/test_formation_planner.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `build_slots(definition, count, radius, seed_angle) -> Array[Vector2]`.

- [ ] **Step 1: Write failing formation tests**

Create a test that loads all seven formation definitions from `GameDatabase`, requests 12 slots from each, asserts exact count and deterministic output, and checks the ring-gap exclusion:

```gdscript
extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/formation_planner.gd"):
		runner.assert_true(false, "formation planner should exist")
		return
	var database_script = load("res://scripts/data/game_database.gd")
	var database = database_script.new()
	runner.assert_true(database.load_all(), "formation test database should load")
	var planner = load("res://scripts/systems/formation_planner.gd").new()
	for formation_id in database.get_formations().keys():
		var formation: Dictionary = database.get_formations()[formation_id]
		var first: Array[Vector2] = planner.build_slots(formation, 12, 360.0, 0.0)
		var second: Array[Vector2] = planner.build_slots(formation, 12, 360.0, 0.0)
		runner.assert_eq(first.size(), 12, "%s should create every requested slot" % formation_id)
		runner.assert_eq(first, second, "%s should be deterministic" % formation_id)
	if database.get_formations().has("surround_gap"):
		var slots: Array[Vector2] = planner.build_slots(database.get_formations()["surround_gap"], 18, 360.0, 0.0)
		for slot in slots:
			runner.assert_true(absf(wrapf(slot.angle(), -PI, PI)) >= deg_to_rad(34.0), "surround should preserve the escape lane")
```

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement formation algorithms**

Create `scripts/systems/formation_planner.gd` with one public dispatcher and seven private builders. Use these exact formulas:

```gdscript
extends RefCounted
class_name FormationPlanner

func build_slots(definition: Dictionary, count: int, radius: float, seed_angle: float) -> Array[Vector2]:
	if count <= 0:
		return []
	var scaled_radius := radius * float(definition.get("radius_scale", 1.0))
	match String(definition.get("pattern", "ring_gap")):
		"wedge": return _wedge(count, scaled_radius, seed_angle, float(definition.get("row_spacing", 62.0)), float(definition.get("column_spacing", 58.0)))
		"escort": return _escort(count, scaled_radius, seed_angle, float(definition.get("front_ratio", 0.72)), float(definition.get("rear_offset", 92.0)))
		"leader_flanks": return _leader_flanks(count, scaled_radius, seed_angle, deg_to_rad(float(definition.get("flank_angle_degrees", 36.0))), float(definition.get("depth_spacing", 64.0)))
		"dual_ring": return _dual_ring(count, scaled_radius, seed_angle, float(definition.get("inner_radius_scale", 0.72)))
		"pincer": return _pincer(count, scaled_radius, seed_angle, deg_to_rad(float(definition.get("side_angle_degrees", 76.0))), float(definition.get("depth_spacing", 54.0)))
		"corridor": return _corridor(count, scaled_radius, seed_angle, float(definition.get("lane_spacing", 68.0)), float(definition.get("depth_spacing", 58.0)))
		_: return _ring_gap(count, scaled_radius, seed_angle, deg_to_rad(float(definition.get("gap_degrees", 70.0))))

func _ring_gap(count: int, radius: float, angle: float, gap: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var usable := TAU - gap
	for index in range(count):
		var phase := (float(index) + 0.5) / float(count)
		result.append(Vector2.RIGHT.rotated(angle + gap * 0.5 + usable * phase) * radius)
	return result

func _wedge(count: int, radius: float, angle: float, row_spacing: float, column_spacing: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	for index in range(count):
		var row := int(floor((sqrt(8.0 * index + 1.0) - 1.0) * 0.5))
		var row_start := row * (row + 1) / 2
		var column := index - row_start
		result.append(forward * (radius + row * row_spacing) + side * (float(column) - float(row) * 0.5) * column_spacing)
	return result

func _escort(count: int, radius: float, angle: float, front_ratio: float, rear_offset: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var front_count := clampi(int(ceil(count * front_ratio)), 1, count)
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	for index in range(count):
		var rear := index >= front_count
		var local_index := index - front_count if rear else index
		var local_count := count - front_count if rear else front_count
		var offset := (float(local_index) - float(maxi(1, local_count) - 1) * 0.5) * 58.0
		result.append(forward * (radius + (rear_offset if rear else 0.0)) + side * offset)
	return result

func _leader_flanks(count: int, radius: float, angle: float, flank_angle: float, depth: float) -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2.RIGHT.rotated(angle) * radius]
	for index in range(1, count):
		var side_sign := -1.0 if index % 2 == 0 else 1.0
		var rank := float((index + 1) / 2)
		result.append(Vector2.RIGHT.rotated(angle + flank_angle * side_sign) * (radius + rank * depth))
	return result

func _dual_ring(count: int, radius: float, angle: float, inner_scale: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(count):
		var ring_radius := radius * (inner_scale if index % 2 == 0 else 1.0)
		result.append(Vector2.RIGHT.rotated(angle + TAU * float(index) / float(count)) * ring_radius)
	return result

func _pincer(count: int, radius: float, angle: float, side_angle: float, depth: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(count):
		var side_sign := -1.0 if index % 2 == 0 else 1.0
		var rank := float(index / 2)
		result.append(Vector2.RIGHT.rotated(angle + side_angle * side_sign) * (radius + rank * depth))
	return result

func _corridor(count: int, radius: float, angle: float, lane_spacing: float, depth: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	for index in range(count):
		var lane := index % 3 - 1
		var rank := index / 3
		result.append(forward * (radius + rank * depth) + side * lane * lane_spacing)
	return result
```

- [ ] **Step 4: Run full suite and commit**

```powershell
git add scripts/systems/formation_planner.gd tests/test_formation_planner.gd tests/run_all_tests.gd
git commit -m "feat: add encounter formation planner"
```

---

### Task 5: Integrate Cards, Queues, and Heavy-Damage Recovery

**Files:**
- Modify: `scripts/systems/enemy_director.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `tests/test_enemy_director.gd`
- Modify: `tests/test_game_loop_summary.gd`

**Interfaces:**
- Produces: `encounter_started(card_id)`, deterministic scheduling, `notify_player_heavy_damage()`, six-spawn frame cap, 140-active cap, and formation positions.

- [ ] **Step 1: Add failing integration assertions**

Replace `FakeDatabase` in `tests/test_enemy_director.gd` with this backward-compatible fixture:

```gdscript
class FakeDatabase:
	extends RefCounted

	var events: Array[Dictionary] = []
	var encounters: Array[Dictionary] = []
	var formations: Dictionary = {
		"surround_gap": {"id": "surround_gap", "pattern": "ring_gap", "gap_degrees": 70.0},
	}
	var enemies: Dictionary = {
		"basic_demon": {"id": "basic_demon", "role": "swarm", "behavior": "chase", "max_health": 24, "move_speed": 70, "experience_value": 1, "material_value": 1},
		"seal_boss": {"id": "seal_boss", "role": "boss", "behavior": "boss", "max_health": 1200, "move_speed": 70, "experience_value": 30, "material_value": 50},
	}

	func _init(new_events: Array[Dictionary] = [], new_encounters: Array[Dictionary] = []) -> void:
		events = new_events
		encounters = new_encounters

	func get_wave_events() -> Array[Dictionary]:
		return events

	func get_enemy(id: String) -> Dictionary:
		return enemies.get(id, {})

	func get_enemies() -> Dictionary:
		return enemies

	func get_encounters() -> Array[Dictionary]:
		return encounters

	func get_formations() -> Dictionary:
		return formations
```

Call `_assert_budgeted_encounter(runner, director_script)` at the end of `run`, then add:

```gdscript

func _assert_budgeted_encounter(runner, director_script) -> void:
	var parent := Node2D.new()
	var player := Node2D.new()
	var director = director_script.new()
	var spawned_enemies: Array[Node] = []
	var started: Array[String] = []
	parent.add_child(player)
	parent.add_child(director)
	Engine.get_main_loop().root.add_child(parent)
	director.enemy_scene = load("res://scenes/enemies/BasicDemon.tscn")
	director.configure(FakeDatabase.new([], [{
		"id": "test_surround",
		"weight": 1,
		"min_time": 45.0,
		"max_time": 300.0,
		"cooldown_draws": 0,
		"pressure_cost": 10,
		"formation_id": "surround_gap",
		"groups": [{"enemy_id": "basic_demon", "count": 10}],
	}]), player)
	director.enemy_spawned.connect(func(enemy: Node) -> void: spawned_enemies.append(enemy))
	director.encounter_started.connect(func(id: String) -> void: started.append(id))
	director.next_encounter_time = 45.0
	director._process(45.0)
	runner.assert_eq(started, ["test_surround"], "director should schedule an eligible encounter")
	runner.assert_true(director.pending_spawn_waves.size() > 0, "encounter should enter the spawn queue")
	director._process(0.0)
	runner.assert_true(spawned_enemies.size() > 0, "queued encounter should begin spawning")
	runner.assert_true(spawned_enemies.size() <= 6, "one frame should respect the spawn burst cap")
	for enemy in spawned_enemies:
		runner.assert_true(enemy.has_meta("encounter_id"), "director enemy should record encounter provenance")
	parent.queue_free()
```

In `tests/test_game_loop_summary.gd`, add this fixture after `FakeHUD`:

```gdscript
class FakeEnemyDirector:
	extends Node

	var heavy_damage_calls: int = 0

	func notify_player_heavy_damage() -> void:
		heavy_damage_calls += 1
```

Append this test near the end of `run`, before final cleanup:

```gdscript
	var pressure_loop = game_loop_script.new()
	var pressure_player := Node2D.new()
	var pressure_health = load("res://scripts/components/health_component.gd").new()
	var pressure_director := FakeEnemyDirector.new()
	pressure_health.name = "HealthComponent"
	pressure_player.add_child(pressure_health)
	pressure_health.configure(100)
	pressure_loop.player = pressure_player
	pressure_loop.enemy_director = pressure_director
	pressure_loop._on_player_damaged(24)
	runner.assert_eq(pressure_director.heavy_damage_calls, 0, "small hit should not suppress pressure")
	pressure_loop._on_player_damaged(25)
	runner.assert_eq(pressure_director.heavy_damage_calls, 1, "quarter-health hit should suppress pressure")
	pressure_director.free()
	pressure_player.free()
	pressure_loop.free()
```

- [ ] **Step 2: Run and verify RED**

Expected: missing signal, scheduling fields, and heavy-damage forwarding.

- [ ] **Step 3: Add director dependencies and state**

At the top of `enemy_director.gd`:

```gdscript
const EncounterBagScript = preload("res://scripts/systems/encounter_bag.gd")
const PressureBudgetScript = preload("res://scripts/systems/pressure_budget.gd")
const FormationPlannerScript = preload("res://scripts/systems/formation_planner.gd")

signal encounter_started(card_id: String)

@export var encounter_seed: int = 20260712
@export var encounter_interval_min: float = 45.0
@export var encounter_interval_max: float = 60.0
@export var max_active_enemies: int = 140
@export var max_spawns_per_frame: int = 6

var encounter_bag = EncounterBagScript.new()
var pressure_budget = PressureBudgetScript.new()
var formation_planner = FormationPlannerScript.new()
var interval_rng := RandomNumberGenerator.new()
var formations: Dictionary = {}
var enemy_definitions: Dictionary = {}
var next_encounter_time: float = 45.0
```

In `configure`, reset all runtime state and configure pure systems:

```gdscript
	elapsed = 0.0
	triggered_events.clear()
	pending_spawn_waves.clear()
	formations = database.get_formations() if database.has_method("get_formations") else {}
	enemy_definitions = database.get_enemies() if database.has_method("get_enemies") else {}
	var cards: Array[Dictionary] = database.get_encounters() if database.has_method("get_encounters") else []
	encounter_bag.configure(cards, encounter_seed)
	interval_rng.seed = encounter_seed ^ 0x5f3759df
	next_encounter_time = encounter_interval_min
```

- [ ] **Step 4: Schedule encounters during `_process`**

After fixed event handling:

```gdscript
	pressure_budget.tick(delta)
	if elapsed >= next_encounter_time:
		_try_schedule_encounter()
		next_encounter_time = elapsed + interval_rng.randf_range(encounter_interval_min, encounter_interval_max)
```

Add:

```gdscript
func notify_player_heavy_damage() -> void:
	pressure_budget.notify_heavy_damage()

func _try_schedule_encounter() -> bool:
	var card: Dictionary = encounter_bag.draw(elapsed, pressure_budget.get_budget(elapsed))
	if card.is_empty():
		return false
	var snapshot := _get_active_snapshot()
	if not pressure_budget.can_schedule(card, enemy_definitions, snapshot["roles"], snapshot["total"], max_active_enemies):
		return false
	_queue_encounter(card)
	encounter_started.emit(String(card.get("id", "")))
	return true

func _get_active_snapshot() -> Dictionary:
	var roles: Dictionary = {}
	var total := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		total += 1
		var role := String(enemy.get_meta("enemy_role", "swarm"))
		roles[role] = int(roles.get(role, 0)) + 1
	return {"roles": roles, "total": total}

func _queue_encounter(card: Dictionary) -> void:
	var total_count := 0
	for group in card.get("groups", []):
		total_count += int(group.get("count", 0))
	var formation: Dictionary = formations.get(String(card.get("formation_id", "")), {})
	var angle := interval_rng.randf_range(-PI, PI)
	var slots := formation_planner.build_slots(formation, total_count, spawn_radius, angle)
	var slot_index := 0
	for group in card.get("groups", []):
		var enemy_id := String(group.get("enemy_id", "basic_demon"))
		var count := int(group.get("count", 0))
		var definition: Dictionary = database.get_enemy(enemy_id).duplicate(true)
		var positions: Array[Vector2] = []
		for index in range(count):
			positions.append(slots[slot_index])
			slot_index += 1
		pending_spawn_waves.append({
			"definition": definition,
			"spawn_count": count,
			"spawn_interval": 0.12,
			"spawned_count": 0,
			"time_until_next_spawn": 0.0,
			"positions": positions,
			"encounter_id": String(card.get("id", "")),
		})
```

- [ ] **Step 5: Enforce spawn caps and provenance**

Add `"positions": []` and `"encounter_id": ""` to the dictionary appended by `_spawn_wave`, then replace `_process_pending_spawn_waves` with:

```gdscript
func _process_pending_spawn_waves(delta: float) -> void:
	var completed_waves: Array[Dictionary] = []
	var remaining_frame_spawns := max_spawns_per_frame
	for wave in pending_spawn_waves:
		if remaining_frame_spawns <= 0:
			break
		var spawned_count := int(wave.get("spawned_count", 0))
		var spawn_count := int(wave.get("spawn_count", 1))
		var spawn_interval := float(wave.get("spawn_interval", 0.0))
		var time_until_next_spawn := float(wave.get("time_until_next_spawn", 0.0)) - delta
		var positions: Array = wave.get("positions", [])
		var encounter_id := String(wave.get("encounter_id", ""))

		while spawned_count < spawn_count and remaining_frame_spawns > 0 and (spawn_interval <= 0.0 or time_until_next_spawn <= SPAWN_TIMER_EPSILON):
			var offset := Vector2.INF
			if spawned_count < positions.size():
				offset = positions[spawned_count]
			if not _spawn_enemy(wave["definition"], spawned_count, spawn_count, offset, encounter_id):
				time_until_next_spawn = maxf(0.1, spawn_interval)
				break
			spawned_count += 1
			remaining_frame_spawns -= 1
			if spawn_interval > 0.0:
				time_until_next_spawn += spawn_interval

		wave["spawned_count"] = spawned_count
		wave["time_until_next_spawn"] = time_until_next_spawn
		if spawned_count >= spawn_count:
			completed_waves.append(wave)

	for wave in completed_waves:
		pending_spawn_waves.erase(wave)
```

Change `_spawn_enemy` to accept `offset`, `encounter_id`, and return `bool`:

```gdscript
func _spawn_enemy(definition: Dictionary, index: int, count: int, offset: Vector2 = Vector2.INF, encounter_id: String = "") -> bool:
	if get_tree().get_nodes_in_group("enemies").size() >= max_active_enemies:
		return false
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	var resolved_offset := Vector2.RIGHT.rotated(TAU * float(index) / max(1, count)) * spawn_radius if offset == Vector2.INF else offset
	enemy.global_position = player.global_position + resolved_offset
	enemy.set_meta("enemy_role", String(definition.get("role", "swarm")))
	if encounter_id != "":
		enemy.set_meta("encounter_id", encounter_id)
	enemy.configure(definition, player)
	enemy_spawned.emit(enemy)
	if bool(definition.get("is_boss", false)) or definition.get("behavior", "") == "boss":
		boss_spawned.emit(enemy)
	return true
```

- [ ] **Step 6: Forward heavy player damage**

In `game_loop.gd`, connect `damaged` to `_on_player_damaged` instead of unbinding it:

```gdscript
func _on_player_damaged(amount: int) -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health == null:
		return
	_update_player_health_hud(player_health)
	var heavy_threshold := int(ceil(float(player_health.get("max_health")) * 0.25))
	if amount >= heavy_threshold and enemy_director != null and enemy_director.has_method("notify_player_heavy_damage"):
		enemy_director.notify_player_heavy_damage()
```

Keep healed connected to `_on_player_health_changed.unbind(1)`.

- [ ] **Step 7: Run full suite and commit**

```powershell
git add scripts/systems/enemy_director.gd scripts/core/game_loop.gd tests/test_enemy_director.gd tests/test_game_loop_summary.gd
git commit -m "feat: integrate budgeted encounter director"
```

---

### Task 6: Fifteen-Minute Deterministic Simulator and Publication

**Files:**
- Create: `scripts/systems/encounter_simulator.gd`
- Create: `tests/test_encounter_simulator.gd`
- Create: `tools/simulate_encounters.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `simulate(cards, duration, seed) -> Dictionary` with draw count, unique count, repeat violations, ranged share, maximum budget, and sequence.

- [ ] **Step 1: Write failing simulation test**

```gdscript
extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/encounter_simulator.gd"):
		runner.assert_true(false, "encounter simulator should exist")
		return
	var database = load("res://scripts/data/game_database.gd").new()
	runner.assert_true(database.load_all(), "simulator database should load")
	var simulator = load("res://scripts/systems/encounter_simulator.gd").new()
	var report: Dictionary = simulator.simulate(database.get_encounters(), 900.0, 20260712)
	runner.assert_true(int(report.get("draw_count", 0)) >= 14, "fifteen minutes should contain repeated encounter draws")
	runner.assert_true(int(report.get("unique_count", 0)) >= 6, "simulation should exercise most encounter cards")
	runner.assert_eq(report.get("triple_repeats", -1), 0, "simulation should contain no triple repeats")
	runner.assert_true(float(report.get("ranged_share", 1.0)) <= 0.35, "simulated ranged share should stay capped")
```

- [ ] **Step 2: Run and verify RED**

- [ ] **Step 3: Implement the simulator**

Create `scripts/systems/encounter_simulator.gd`:

```gdscript
extends RefCounted
class_name EncounterSimulator

const EncounterBagScript = preload("res://scripts/systems/encounter_bag.gd")
const PressureBudgetScript = preload("res://scripts/systems/pressure_budget.gd")

func simulate(cards: Array[Dictionary], duration: float, seed: int) -> Dictionary:
	var bag = EncounterBagScript.new()
	var budget = PressureBudgetScript.new()
	bag.configure(cards, seed)
	var elapsed := 45.0
	var sequence: Array[String] = []
	var unique: Dictionary = {}
	var triple_repeats := 0
	var ranged_units := 0
	var total_units := 0
	var max_budget := 0
	while elapsed <= duration:
		var available := budget.get_budget(elapsed)
		max_budget = maxi(max_budget, available)
		var card: Dictionary = bag.draw(elapsed, available)
		if not card.is_empty():
			var id := String(card.get("id", ""))
			sequence.append(id)
			unique[id] = true
			if sequence.size() >= 3 and sequence[-1] == sequence[-2] and sequence[-2] == sequence[-3]:
				triple_repeats += 1
			for group in card.get("groups", []):
				var count := int(group.get("count", 0))
				total_units += count
				if String(group.get("enemy_id", "")) == "ranged_demon":
					ranged_units += count
		elapsed += 52.0
	return {
		"draw_count": sequence.size(),
		"unique_count": unique.size(),
		"triple_repeats": triple_repeats,
		"ranged_share": float(ranged_units) / float(maxi(1, total_units)),
		"max_budget": max_budget,
		"sequence": sequence,
	}
```

- [ ] **Step 4: Add CLI entrypoint**

Create `tools/simulate_encounters.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	var database = load("res://scripts/data/game_database.gd").new()
	if not database.load_all():
		push_error("Database errors: %s" % str(database.errors))
		quit(1)
		return
	var simulator = load("res://scripts/systems/encounter_simulator.gd").new()
	var report: Dictionary = simulator.simulate(database.get_encounters(), 900.0, 20260712)
	print(JSON.stringify(report))
	var valid := int(report.get("triple_repeats", 1)) == 0 and int(report.get("unique_count", 0)) >= 6 and float(report.get("ranged_share", 1.0)) <= 0.35
	quit(0 if valid else 1)
```

- [ ] **Step 5: Run full verification**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --editor --path . --import
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tools/simulate_encounters.gd
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit-after 600
git diff --check
```

Expected: import exits 0, tests print `All tests passed.`, simulator exits 0 with no triple repeats and at least six unique cards, and the 600-frame scene smoke exits 0.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/systems/encounter_simulator.gd tests/test_encounter_simulator.gd tools/simulate_encounters.gd tests/run_all_tests.gd
git commit -m "test: add encounter director simulation"
git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c http.version=HTTP/1.1 -c core.compression=9 push --progress origin main
```

---

## Plan Self-Review

- Scope coverage: implements the approved hybrid director, deterministic weighted cards, time pressure, ±15% adjustment, heavy-damage recovery, ranged/control caps, seven formations, active and frame spawn caps, queue preservation, and a 15-minute simulator.
- Scope boundary: enemy/projectile/pickup/effect object pools are deliberately a separate next plan because pooled nodes need resettable health, action, signal, and ownership contracts.
- Fixed-wave compatibility: the existing `first_run.json` path remains active; encounter cards add pressure and never replace boss or elite story events.
- Type consistency: all content flows as `Dictionary`/`Array[Dictionary]`; pure systems never access scenes; `EnemyDirector` alone instantiates nodes.
- Repeat consistency: bag history checks both card IDs and sorted enemy signatures before every draw.
- Mobile consistency: active cap is 140, burst cap is 6, surround gap is 70 degrees, and first-chapter spawn radius remains 360 for the current portrait readability target.
- Verification consistency: content references, pure logic, scene integration, deterministic simulation, full tests, and a 600-frame smoke each have explicit evidence.
