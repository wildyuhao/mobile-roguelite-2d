# Modular Weapons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the controlled weapon-effect pipeline, four carrier types, four statuses, and the first eight production weapons defined in `docs/superpowers/specs/2026-07-13-modular-weapons-design.md`.

**Architecture:** `WeaponSystem` remains the scene-facing runtime but emits immutable effect requests instead of executing attacks. `CombatEffectPipeline` selects targets, acquires a registered carrier, and routes every hit through `HitResolver` and `StatusController`; carriers never call `HealthComponent.take_damage()` directly. Weapon definitions contain one to three registered linear effects and are rejected at database load when their schema or references are invalid.

**Tech Stack:** Godot 4.7 stable, GDScript, JSON content definitions, existing `PoolService`, built-in image-2, Pillow-based local sprite tools.

## Global Constraints

- Keep the portrait reference viewport at 720x1280 and preserve the current left virtual joystick layout.
- Keep exactly four weapon slots; a runtime/config override cannot raise the cap above four.
- Preserve the existing IDs `flying_sword`, `talisman_fire`, `mechanism_crossbow`, `demon_sealing_bell`, and `spirit_needle_array`.
- Do not store executable code, arbitrary property paths, or cyclic effect references in JSON.
- Every player-weapon damage event, including splash, summon attacks, reactions, and status damage, must pass through `HitResolver`.
- Freeze and seal cannot skip enemy windup, active, recovery, or death transitions.
- Pool caps: 250 projectiles, 24 areas, 32 orbit entities, and 12 summons before evolution content exists.
- Player effects cannot use solid threat red as their dominant color.
- Green-screen sources go to `art/source_green`; transparent production assets go to their weapon/status directories.
- Add behavior with RED/GREEN tests and keep full Godot output free of parser errors and warnings.

Before running plan commands in PowerShell, set:

```powershell
$env:GODOT = 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe'
```

---

### Task 1: Weapon Definition Registry And Validation

**Files:**
- Create: `scripts/weapons/weapon_definition_validator.gd`
- Create: `tests/test_weapon_definition_validator.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `WeaponDefinitionValidator.validate(definition: Dictionary) -> Array[String]`
- Produces: `WeaponDefinitionValidator.validate_catalog(definitions: Dictionary) -> Array[String]`
- Registered trigger IDs: `periodic`, `persistent`, `on_player_hit`, `on_kill`
- Registered target IDs: `nearest`, `lowest_health`, `sector`, `radial`, `self`
- Registered carrier IDs: `projectile`, `area`, `orbit`, `summon`
- Registered status IDs: `burn`, `freeze`, `armor_break`, `seal`

- [ ] **Step 1: Add the validator test to the runner**

Insert `res://tests/test_weapon_definition_validator.gd` immediately before `test_weapon_system.gd` in `TEST_SCRIPTS`.

- [ ] **Step 2: Write the failing validator test**

```gdscript
extends RefCounted

const ValidatorScript = preload("res://scripts/weapons/weapon_definition_validator.gd")

func run(runner) -> void:
	var validator = ValidatorScript.new()
	var valid := {
		"id": "test_weapon",
		"version": 1,
		"display_name": "测试武器",
		"description": "用于验证模块化武器结构。",
		"school": "sword",
		"max_level": 5,
		"effects": [{
			"effect_id": "main",
			"trigger": { "id": "periodic", "cooldown": 1.0 },
			"target": { "id": "nearest", "range": 320.0 },
			"carrier": { "id": "projectile", "speed": 500.0, "count": 1 },
			"hit": { "damage": 10, "statuses": [] },
		}],
		"visual": { "carrier": "res://art/weapons/flying_sword/flying_sword_projectile.png" },
		"levels": [],
	}
	runner.assert_true(validator.validate(valid).is_empty(), "valid modular weapon should pass")

	var invalid := valid.duplicate(true)
	invalid["effects"][0]["carrier"]["id"] = "script_string"
	invalid["effects"].append(invalid["effects"][0].duplicate(true))
	var errors := validator.validate(invalid)
	runner.assert_true(_contains(errors, "unknown carrier"), "unknown carrier should fail")
	runner.assert_true(_contains(errors, "duplicate effect_id"), "duplicate effect id should fail")

	invalid = valid.duplicate(true)
	invalid["levels"] = [{
		"level": 2,
		"effect_id": "missing",
		"section": "hit",
		"values": { "damage": 20, "script_path": "res://bad.gd" },
	}]
	errors = validator.validate(invalid)
	runner.assert_true(
		_contains(errors, "missing effect_id"),
		"level override should reference an existing effect"
	)
	runner.assert_true(_contains(errors, "unsupported override"), "arbitrary override fields should fail")

func _contains(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false
```

- [ ] **Step 3: Run RED**

Run:

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
```

Expected: the runner reports that `weapon_definition_validator.gd` cannot be loaded.

- [ ] **Step 4: Implement the controlled validator**

```gdscript
extends RefCounted
class_name WeaponDefinitionValidator

const TRIGGERS := { "periodic": true, "persistent": true, "on_player_hit": true, "on_kill": true }
const TARGETS := { "nearest": true, "lowest_health": true, "sector": true, "radial": true, "self": true }
const CARRIERS := { "projectile": true, "area": true, "orbit": true, "summon": true }
const STATUSES := { "burn": true, "freeze": true, "armor_break": true, "seal": true }
const SECTIONS := { "trigger": true, "target": true, "carrier": true, "hit": true }
const OVERRIDE_FIELDS := {
	"trigger": { "cooldown": true, "event_cooldown": true },
	"target": { "range": true, "angle_degrees": true },
	"carrier": {
		"speed": true, "count": true, "pierce": true, "duration": true,
		"hit_interval": true, "radius": true, "angular_speed": true,
		"lifetime": true, "move_speed": true, "attack_interval": true,
		"attack_range": true,
	},
	"hit": {
		"damage": true, "splash_radius": true, "knockback": true,
		"statuses": true, "hit_effect_id": true,
	},
}

func validate(definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var weapon_id := String(definition.get("id", ""))
	if weapon_id == "": errors.append("weapon has empty id")
	if int(definition.get("version", 0)) != 1: errors.append("%s has unsupported version" % weapon_id)
	if String(definition.get("display_name", "")) == "": errors.append("%s has empty display_name" % weapon_id)
	if String(definition.get("school", "")) == "": errors.append("%s has empty school" % weapon_id)
	if int(definition.get("max_level", 0)) != 5: errors.append("%s max_level must be 5" % weapon_id)

	var effects: Array = definition.get("effects", [])
	if effects.is_empty() or effects.size() > 3:
		errors.append("%s must define one to three effects" % weapon_id)
	var effect_ids := {}
	for effect in effects:
		var effect_id := String(effect.get("effect_id", ""))
		if effect_id == "" or effect_ids.has(effect_id):
			errors.append("%s has duplicate effect_id %s" % [weapon_id, effect_id])
		effect_ids[effect_id] = true
		_validate_module(errors, weapon_id, effect_id, "trigger", effect.get("trigger", {}), TRIGGERS)
		_validate_module(errors, weapon_id, effect_id, "target", effect.get("target", {}), TARGETS)
		_validate_module(errors, weapon_id, effect_id, "carrier", effect.get("carrier", {}), CARRIERS)
		_validate_effect_bounds(errors, weapon_id, effect_id, effect)
		var hit: Dictionary = effect.get("hit", {})
		if int(hit.get("damage", 0)) < 0: errors.append("%s/%s has negative damage" % [weapon_id, effect_id])
		for status in hit.get("statuses", []):
			if not STATUSES.has(String(status.get("id", ""))):
				errors.append("%s/%s has unknown status" % [weapon_id, effect_id])
			if int(status.get("stacks", 0)) <= 0 or float(status.get("duration", 0.0)) <= 0.0:
				errors.append("%s/%s has invalid status stacks or duration" % [weapon_id, effect_id])

	for level in definition.get("levels", []):
		var effect_id := String(level.get("effect_id", ""))
		if not effect_ids.has(effect_id): errors.append("%s level references missing effect_id %s" % [weapon_id, effect_id])
		var section := String(level.get("section", ""))
		if not SECTIONS.has(section):
			errors.append("%s level has invalid section" % weapon_id)
		else:
			for key in Dictionary(level.get("values", {})).keys():
				if not OVERRIDE_FIELDS[section].has(String(key)):
					errors.append("%s level has unsupported override %s" % [weapon_id, key])
		if int(level.get("level", 0)) < 2 or int(level.get("level", 0)) > 5: errors.append("%s level is outside 2..5" % weapon_id)
	var visuals: Dictionary = definition.get("visual", {})
	if visuals.is_empty(): errors.append("%s has no visual references" % weapon_id)
	for path in visuals.values():
		var resource_path := String(path)
		if resource_path != "" and (not resource_path.begins_with("res://") or not ResourceLoader.exists(resource_path)):
			errors.append("%s references missing visual %s" % [weapon_id, resource_path])
	return errors

func validate_catalog(definitions: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for definition in definitions.values():
		errors.append_array(validate(definition))
	return errors

func _validate_module(errors: Array[String], weapon_id: String, effect_id: String, label: String, module: Dictionary, registry: Dictionary) -> void:
	var module_id := String(module.get("id", ""))
	if not registry.has(module_id): errors.append("%s/%s has unknown %s %s" % [weapon_id, effect_id, label, module_id])
	if label == "trigger" and module_id == "periodic" and float(module.get("cooldown", 0.0)) <= 0.0:
		errors.append("%s/%s periodic cooldown must be positive" % [weapon_id, effect_id])

func _validate_effect_bounds(errors: Array[String], weapon_id: String, effect_id: String, effect: Dictionary) -> void:
	var target: Dictionary = effect.get("target", {})
	var carrier: Dictionary = effect.get("carrier", {})
	if String(target.get("id", "")) != "self" and float(target.get("range", 0.0)) <= 0.0:
		errors.append("%s/%s target range must be positive" % [weapon_id, effect_id])
	var count := int(carrier.get("count", 1))
	if count <= 0 or count > 12: errors.append("%s/%s carrier count is outside 1..12" % [weapon_id, effect_id])
	if float(carrier.get("duration", 0.0)) < 0.0: errors.append("%s/%s has negative duration" % [weapon_id, effect_id])
	if float(carrier.get("hit_interval", 0.1)) < 0.1: errors.append("%s/%s hit_interval must be at least 0.1" % [weapon_id, effect_id])
	if String(carrier.get("id", "")) == "orbit" and count > 8: errors.append("%s/%s orbit count exceeds 8" % [weapon_id, effect_id])
	if String(carrier.get("id", "")) == "summon" and count > 6: errors.append("%s/%s summon count exceeds 6" % [weapon_id, effect_id])
```

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
git add scripts/weapons/weapon_definition_validator.gd tests/test_weapon_definition_validator.gd tests/run_all_tests.gd
git commit -m "feat: validate modular weapon definitions"
```

Expected: `All tests passed.` and one new commit.

---

### Task 2: Effect Requests And Trigger Runtime

**Files:**
- Create: `scripts/weapons/weapon_request_builder.gd`
- Modify: `scripts/systems/weapon_system.gd`
- Modify: `tests/test_weapon_system.gd`

**Interfaces:**
- Produces: `WeaponRequestBuilder.resolve_effects(definition: Dictionary, level: int) -> Array[Dictionary]`
- Produces: `WeaponSystem.tick(delta: float) -> Array[Dictionary]`
- Produces: `WeaponSystem.notify_trigger(trigger_id: String, payload: Dictionary) -> Array[Dictionary]`
- Produces: `WeaponSystem.acknowledge_request(request_id: int, result: String) -> void`
- Effect request keys: `request_id`, `weapon_id`, `effect_id`, `trigger`, `target`, `carrier`, `hit`, `visual`, `trigger_payload`

- [ ] **Step 1: Write RED tests for periodic, persistent, event and level requests**

Add a local `_modular_fixture()` to `tests/test_weapon_system.gd` returning one periodic effect, one persistent effect, and one `on_player_hit` effect. Assert:

```gdscript
var modular = weapon_system_script.new()
runner.assert_true(modular.add_weapon(_modular_fixture()), "modular fixture should equip")
var first_requests = modular.tick(0.0)
runner.assert_eq(_count_effect(first_requests, "orbit"), 1, "persistent effect should emit once")
runner.assert_eq(modular.tick(0.5).size(), 0, "periodic effect should wait")
var periodic = modular.tick(0.6)
runner.assert_eq(_count_effect(periodic, "bolt"), 1, "periodic effect should emit after cooldown")
modular.acknowledge_request(int(periodic[0]["request_id"]), "no_target")
runner.assert_eq(_count_effect(modular.tick(0.11), "bolt"), 1, "no target should retry after 0.1 seconds")
var retaliation = modular.notify_trigger("on_player_hit", { "damage": 8 })
runner.assert_eq(_count_effect(retaliation, "retaliate"), 1, "player hit trigger should emit")
modular.level_weapon("fixture_weapon")
var refreshed = modular.tick(0.0)
runner.assert_eq(_request_damage(refreshed, "orbit"), 14, "level override should refresh persistent effect")
```

The fixture must use whitelist overrides:

```gdscript
"levels": [{
	"level": 2,
	"effect_id": "orbit",
	"section": "hit",
	"values": { "damage": 14 },
}]
```

- [ ] **Step 2: Run RED**

Run the full Godot test command. Expected failures mention missing modular requests, `acknowledge_request`, and `notify_trigger`.

- [ ] **Step 3: Implement the request builder**

```gdscript
extends RefCounted
class_name WeaponRequestBuilder

func resolve_effects(definition: Dictionary, level: int) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for raw_effect in definition.get("effects", []):
		effects.append(raw_effect.duplicate(true))
	for override in definition.get("levels", []):
		if int(override.get("level", 0)) > level:
			continue
		var effect := _find_effect(effects, String(override.get("effect_id", "")))
		var section := String(override.get("section", ""))
		if effect.is_empty() or not effect.has(section):
			continue
		for key in Dictionary(override.get("values", {})).keys():
			effect[section][key] = override["values"][key]
	return effects

func _find_effect(effects: Array[Dictionary], effect_id: String) -> Dictionary:
	for effect in effects:
		if String(effect.get("effect_id", "")) == effect_id:
			return effect
	return {}
```

- [ ] **Step 4: Add modular effect state to `WeaponSystem`**

Use `WeaponRequestBuilder` when `definition.version == 1`. Store per-effect `remaining`, `persistent_pending`, and `event_remaining`. Increment a monotonic `next_request_id`; map emitted request IDs back to their weapon/effect state. Preserve the current flat-definition branch only until Task 6 migrates all five live definitions.

The request constructor must be:

```gdscript
func _make_request(weapon_id: String, effect: Dictionary, payload: Dictionary = {}) -> Dictionary:
	var request_id := next_request_id
	next_request_id += 1
	pending_request_effects[request_id] = {
		"weapon_id": weapon_id,
		"effect_id": String(effect.get("effect_id", "")),
	}
	return {
		"request_id": request_id,
		"weapon_id": weapon_id,
		"effect_id": String(effect.get("effect_id", "")),
		"trigger": Dictionary(effect.get("trigger", {})).duplicate(true),
		"target": Dictionary(effect.get("target", {})).duplicate(true),
		"carrier": Dictionary(effect.get("carrier", {})).duplicate(true),
		"hit": Dictionary(effect.get("hit", {})).duplicate(true),
		"visual": Dictionary(weapons[weapon_id]["definition"].get("visual", {})).duplicate(true),
		"trigger_payload": payload.duplicate(true),
	}
```

`acknowledge_request(..., "no_target")` sets that periodic effect's remaining time to `min(current, 0.1)`. `pool_queued` and `executed` only clear request bookkeeping. `persistent` emits once on equip and once after a level changes its resolved fields.

- [ ] **Step 5: Run GREEN and commit**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
git add scripts/weapons/weapon_request_builder.gd scripts/systems/weapon_system.gd tests/test_weapon_system.gd
git commit -m "feat: emit modular weapon effect requests"
```

---

### Task 3: Unified Hit Resolver And Status Controller

**Files:**
- Create: `scripts/systems/hit_resolver.gd`
- Create: `scripts/components/status_controller.gd`
- Create: `tests/test_hit_resolver.gd`
- Create: `tests/test_status_controller.gd`
- Modify: `scripts/systems/enemy_action_state.gd`
- Modify: `scripts/enemies/enemy_agent.gd`
- Modify: `scenes/enemies/BasicDemon.tscn`
- Modify: `tests/test_enemy_action_state.gd`
- Modify: `tests/test_enemy_agent.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `HitResolver.resolve(target: Node, packet: Dictionary) -> Dictionary`
- Produces: `HitResolver.resolve_status_damage(target: Node, packet: Dictionary) -> Dictionary`
- Produces: `StatusController.apply_status(payload: Dictionary, source: Dictionary) -> Dictionary`
- Produces: `StatusController.tick_statuses(delta: float) -> Array[Dictionary]`
- Produces: `get_damage_multiplier(tags: Array)`, `get_movement_multiplier()`, `get_action_time_scale()`, `can_start_special()`, `clear_all()`
- Signal: `status_damage_requested(target: Node, packet: Dictionary)`
- Signal: `status_changed(snapshot: Dictionary)`

- [ ] **Step 1: Register and write RED tests**

Add both new tests before combat integration tests. Build a target `Node2D` with `HealthComponent` and `StatusController`. Cover:

```gdscript
resolver.resolve(target, { "base_damage": 10, "damage_tags": ["direct"], "status_payloads": [] })
runner.assert_eq(health.current_health, 90, "direct hit should damage once")
status.apply_status({ "id": "armor_break", "duration": 3.0 }, { "weapon_id": "crossbow" })
resolver.resolve(target, { "base_damage": 10, "damage_tags": ["direct"], "status_payloads": [] })
runner.assert_eq(health.current_health, 78, "armor break should round 11.5 to 12")
```

Status tests must assert burn caps at three, burn ticks every 0.5 seconds for 2 damage per stack, freeze triggers at three chill applications, normal freeze lasts 1.25 seconds, freeze immunity limits chill to one for 1.5 seconds, seal blocks special starts, death clears statuses, and burn applied to a frozen target returns exactly 18 `thermal_shatter_damage` with a 0.75-second reaction cooldown.

Enemy action tests must start an attack, call `tick(1.0, 0.0)`, and assert state/remaining are unchanged; then resume with scale `1.0` and observe `WINDUP -> ACTIVE -> RECOVERY` in order.

- [ ] **Step 2: Run RED**

Expected: missing `HitResolver`, `StatusController`, and the second `EnemyActionState.tick` parameter.

- [ ] **Step 3: Implement `StatusController`**

Use a dictionary keyed by status ID. Store `remaining`, `stacks`, `source`, and reaction timestamps. `apply_status` returns:

```gdscript
{
	"applied": true,
	"status_id": status_id,
	"thermal_shatter_damage": reaction_damage,
	"consumed_statuses": consumed,
}
```

Rules are exact: burn max 3 and ticks every 0.5 seconds for `2 * stacks`; chill application uses status ID `freeze` and freezes on three stacks for 1.25 seconds; armor break is one stack and `1.15` direct-damage multiplier; seal blocks special starts; normal enemies freeze at action scale `0.0`, bosses at `0.35`; post-freeze immunity lasts `1.5` seconds; thermal shatter deals 18 status damage and cannot repeat for `0.75` seconds. `tick_statuses` emits `status_damage_requested(target, packet)` and also returns the emitted packets for deterministic tests; live callers use the signal only, while the headless simulator uses the return value only. Every apply, expiry, reaction, immunity change, and `clear_all()` emits one aggregated `status_changed(get_snapshot())` update.

- [ ] **Step 4: Implement `HitResolver`**

Resolve existing status damage modifiers before direct damage, set target metadata `last_weapon_id` from `source_weapon_id`, call `HealthComponent.take_damage()` once, then apply status payloads. If `thermal_shatter_damage > 0`, call `resolve_status_damage` with tags `["reaction", "status_damage"]`; this path ignores armor break and cannot apply more statuses. Return the actual damage, applied status IDs, death state, and reaction damage. Extend `EnemyAgent.get_defeat_payload()` to include `source_weapon_id`; remove `last_weapon_id` in both `activate_from_pool()` and `begin_pool_release()` so attribution survives the defeat signal but never leaks into the next pooled enemy.

- [ ] **Step 5: Integrate action-safe status queries**

Change `EnemyActionState.tick` to:

```gdscript
func tick(delta: float, time_scale: float = 1.0) -> Array[String]:
	var transitions: Array[String] = []
	if state == LOCOMOTION or state == DEAD:
		return transitions
	remaining -= maxf(0.0, delta) * clampf(time_scale, 0.0, 1.0)
	while remaining <= 0.0 and state != LOCOMOTION and state != DEAD:
		var overflow := -remaining
		match state:
			WINDUP:
				state = ACTIVE
				remaining = active_duration - overflow
			ACTIVE:
				state = RECOVERY
				remaining = recovery_duration - overflow
			RECOVERY:
				state = LOCOMOTION
				remaining = 0.0
		transitions.append(state)
	return transitions
```

Add `StatusController` to `BasicDemon.tscn`. In `EnemyAgent.calculate_action_velocity`, tick statuses first, pass action scale to `action_state.tick`, multiply locomotion by the movement multiplier, and refuse only charge/ranged/summon/support starts when `can_start_special()` is false. `_on_died` calls `status_controller.clear_all()` before pool release. Do not alter active damage collision behavior.

- [ ] **Step 6: Run GREEN and commit**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
git add scripts/systems/hit_resolver.gd scripts/components/status_controller.gd scripts/systems/enemy_action_state.gd scripts/enemies/enemy_agent.gd scenes/enemies/BasicDemon.tscn tests/test_hit_resolver.gd tests/test_status_controller.gd tests/test_enemy_action_state.gd tests/test_enemy_agent.gd tests/run_all_tests.gd
git commit -m "feat: add action-safe weapon statuses"
```

---

### Task 4: Target Selection, Pool Limits, Projectile And Area Pipeline

**Files:**
- Create: `scripts/weapons/target_selector.gd`
- Create: `scripts/systems/combat_effect_pipeline.gd`
- Create: `scripts/weapons/carriers/projectile_carrier.gd`
- Create: `scripts/weapons/carriers/area_carrier.gd`
- Create: `scenes/weapons/ProjectileCarrier.tscn`
- Create: `scenes/weapons/AreaCarrier.tscn`
- Create: `tests/test_target_selector.gd`
- Create: `tests/test_combat_effect_pipeline.gd`
- Create: `tests/test_area_carrier.gd`
- Modify: `scripts/systems/pool_service.gd`
- Modify: `tests/test_pool_service.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: `TargetSelector.select(target_definition, origin, candidates, context) -> Dictionary`
- Produces: `CombatEffectPipeline.execute_request(request, context) -> String`
- Produces: `CombatEffectPipeline.register_target(target: Node) -> void`
- Produces: `PoolService.set_limit(pool_key: String, max_created: int) -> void`
- Carrier signal: `hit_requested(target: Node, packet: Dictionary)`
- Carrier signal: `release_requested(node: Node)`
- Pipeline signal: `hit_resolved(target: Node, result: Dictionary)`
- Pipeline signal: `status_applied(target: Node, status_id: String)`

- [ ] **Step 1: Write RED target and pool tests**

Target tests cover nearest, lowest health ratio, sector angle, radial direction count, self origin, tie-breaking by candidate array order, and empty results. Pool test sets a limit of two, acquires twice, and asserts the third acquire returns `null` until one node is released.

- [ ] **Step 2: Write RED pipeline and carrier tests**

Construct a pipeline with injected fake scenes and a context:

```gdscript
{
	"origin": Vector2.ZERO,
	"owner": owner,
	"targets": [enemy],
	"pool_service": pool,
	"parent": root,
	"run_time": 0.0,
}
```

Assert `no_target` for an empty candidate list, `executed` for a valid projectile, `pool_queued` when the projectile cap is reached, and one `HitResolver` call when a projectile or area carrier emits `hit_requested`.

- [ ] **Step 3: Implement deterministic target selection**

Use input array order as the final stable tie-breaker. `radial` returns `directions`; `self` returns the origin; target modes return `targets` and a primary direction. `sector` uses `context["aim_direction"]`, falling back to the nearest valid target direction and then `Vector2.RIGHT`. Never call `get_nodes_in_group` inside `TargetSelector`.

- [ ] **Step 4: Add pool limits**

`set_limit` clamps each limit to at least one. `acquire` may instantiate only when `created_counts[pool_key] < limits[pool_key]`; otherwise it returns `null`. Releasing and reacquiring a node must not increase `created_counts`.

- [ ] **Step 5: Implement projectile and area carriers**

Both carriers accept `configure_from_request(selection, request, owner)`. They build the exact hit packet from request fields and emit `hit_requested`; neither script imports `HealthComponent` nor calls `take_damage`. Reset lifetime, hit cooldown dictionaries, texture, tint, collision and owner references in `activate_from_pool`/`deactivate_for_pool`.

Area carriers support `duration == 0` as one pulse and positive duration with `hit_interval >= 0.1`. The same target cannot receive damage twice inside the interval.

- [ ] **Step 6: Implement `CombatEffectPipeline`**

Preload `TargetSelector` and `HitResolver`. Register scenes by carrier ID. If `PoolService.acquire` returns null, append the immutable request/context snapshot to a FIFO queue capped at 32 and return `pool_queued`. `_physics_process` retries queued requests once per frame without duplicating queue entries. `register_target` connects its `StatusController.status_damage_requested` signal to `HitResolver.resolve_status_damage`.

- [ ] **Step 7: Run GREEN and commit**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
git add scripts/weapons/target_selector.gd scripts/systems/combat_effect_pipeline.gd scripts/weapons/carriers/projectile_carrier.gd scripts/weapons/carriers/area_carrier.gd scenes/weapons/ProjectileCarrier.tscn scenes/weapons/AreaCarrier.tscn scripts/systems/pool_service.gd tests/test_target_selector.gd tests/test_combat_effect_pipeline.gd tests/test_area_carrier.gd tests/test_pool_service.gd tests/run_all_tests.gd
git commit -m "feat: add projectile and area effect pipeline"
```

---

### Task 5: Orbit And Summon Carriers

**Files:**
- Create: `scripts/weapons/carriers/orbit_carrier.gd`
- Create: `scripts/weapons/carriers/summon_carrier.gd`
- Create: `scenes/weapons/OrbitCarrier.tscn`
- Create: `scenes/weapons/SummonCarrier.tscn`
- Create: `tests/test_orbit_carrier.gd`
- Create: `tests/test_summon_carrier.gd`
- Modify: `scripts/systems/combat_effect_pipeline.gd`
- Modify: `tests/test_combat_effect_pipeline.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Orbit request fields: `radius`, `angular_speed`, `count`, `hit_interval`, `duration`
- Summon request fields: `count`, `lifetime`, `move_speed`, `attack_interval`, `attack_range`
- Produces: `CombatEffectPipeline.update_context(context: Dictionary) -> void`

- [ ] **Step 1: Write RED orbit tests**

Configure two orbit entities around an owner. Advance one second and assert they remain opposite, follow owner movement, and emit at most one hit per target inside `hit_interval`. Deactivate/reactivate and assert angle, target hit history, owner and request are reset.

- [ ] **Step 2: Write RED summon tests**

Pass two candidates through `update_context`; assert the summon chooses nearest, moves no farther than `move_speed * delta`, emits one hit after entering range, respects `attack_interval`, retargets after its target becomes invalid, and requests release at lifetime expiry. Pool reuse must clear old target and attack timer.

- [ ] **Step 3: Implement orbit carrier**

Each pooled node represents one orbit entity and receives `orbit_index`/`orbit_count`. Position is `owner.global_position + Vector2.RIGHT.rotated(base_angle + elapsed * angular_speed) * radius`. Collision emits the shared hit packet with per-target cooldown. A persistent effect reconfiguration updates existing nodes keyed by `weapon_id/effect_id` instead of spawning duplicates.

- [ ] **Step 4: Implement summon carrier**

The summon receives candidate arrays only through `update_context`; it does not query groups. It selects nearest valid target, moves, and emits a hit only when its attack timer is ready and the target is within range. Its attack has no per-frame contact damage.

- [ ] **Step 5: Register both carriers and enforce counts**

Pipeline limits orbit count to 8 per weapon and summons to 6 per weapon/12 total. Invalid counts return `invalid_request` in tests and produce a development error message with weapon/effect IDs.

- [ ] **Step 6: Run GREEN and commit**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
git add scripts/weapons/carriers/orbit_carrier.gd scripts/weapons/carriers/summon_carrier.gd scenes/weapons/OrbitCarrier.tscn scenes/weapons/SummonCarrier.tscn scripts/systems/combat_effect_pipeline.gd tests/test_orbit_carrier.gd tests/test_summon_carrier.gd tests/test_combat_effect_pipeline.gd tests/run_all_tests.gd
git commit -m "feat: add orbit and summon weapon carriers"
```

---

### Task 6: Migrate The Existing Five Weapons And Live Game

**Files:**
- Modify: `data/weapons/flying_sword.json`
- Modify: `data/weapons/talisman_fire.json`
- Modify: `data/weapons/mechanism_crossbow.json`
- Modify: `data/weapons/demon_sealing_bell.json`
- Modify: `data/weapons/spirit_needle_array.json`
- Modify: `scripts/data/game_database.gd`
- Modify: `scripts/systems/weapon_system.gd`
- Modify: `scripts/core/game_loop.gd`
- Modify: `scenes/game/Game.tscn`
- Modify: `tests/test_game_database.gd`
- Modify: `tests/test_game_loop_summary.gd`
- Modify: `tests/test_game_scene_composition.gd`
- Modify: `tests/test_projectile.gd`
- Delete: `scripts/weapons/projectile.gd`
- Delete: `scenes/weapons/Projectile.tscn`

**Interfaces:**
- Consumes all Task 1-5 interfaces.
- Produces a live `CombatEffectPipeline` scene node configured with the four carrier scenes and local `PoolService`.

- [ ] **Step 1: Write RED migration tests**

Update database expectations so all five definitions have `version == 1`, one to three effects, no legacy top-level `type`, `base_damage`, `cooldown`, or `projectile_speed`, and zero validator errors. Update scene composition to require `CombatEffectPipeline` and all four carrier scene resources.

Add a source-level assertion that `game_loop.gd` contains neither `weapon_type` nor `_apply_pulse_event`; this protects the architectural boundary rather than a particular output.

- [ ] **Step 2: Run RED**

Expected: five schema failures, missing pipeline node, and legacy branch assertions.

- [ ] **Step 3: Migrate the five JSON definitions**

Use these exact primary signatures:

| Weapon | Trigger | Target | Carrier | Hit/status |
| --- | --- | --- | --- | --- |
| `flying_sword` | periodic 0.9 | nearest 420 | projectile 560 | 12 direct, level 4 pierce, level 5 count 2 |
| `talisman_fire` | periodic 1.15 | nearest 360 | projectile 440 | 9 splash 72, burn 1/3.0s |
| `mechanism_crossbow` | periodic 0.45 | lowest_health 520 | projectile 680 | 7 direct, pierce 1, level 5 armor break 3.0s |
| `demon_sealing_bell` | periodic 2.2 | self 180 | area duration 0 | 8 damage, knockback 80, level 5 seal 1.2s |
| `spirit_needle_array` | periodic 1.2 | radial 300 | projectile 520/count 6 | 4 direct, level 4 armor break 2.0s |

Use section/value level overrides and preserve the current Chinese names/descriptions and visual asset paths.

- [ ] **Step 4: Enforce validation at database load**

Preload `WeaponDefinitionValidator`, call `validate_catalog(weapons)` immediately after loading weapon files, and append every returned message to `GameDatabase.errors`. Do not add a legacy conversion path.

Keep the public inspection methods used by UI/tests, but read them from the resolved primary effect: `get_weapon_damage` reads `hit.damage`, `get_weapon_cooldown` reads `trigger.cooldown`, `get_weapon_pierce` reads `carrier.pierce`, and `get_weapon_range` reads `target.range`. Continue applying global damage/cooldown modifiers there. Remove obsolete `get_weapon_stun_chance`; seal is represented only as a status payload.

- [ ] **Step 5: Wire the live scene and coordinator**

Add `CombatEffectPipeline` to `Game.tscn` and export/inject all carrier scenes. In `GameLoop._process`, replace the type branch with:

```gdscript
var context := _build_combat_context()
combat_effect_pipeline.update_context(context)
for request in weapon_system.tick(delta):
	var result := combat_effect_pipeline.execute_request(request, context)
	weapon_system.acknowledge_request(int(request["request_id"]), result)
```

`_build_combat_context` is the only place that reads the enemy group. `_on_player_damaged` forwards `on_player_hit`; `_on_enemy_spawned` calls `register_target`; `_on_enemy_defeated` forwards `on_kill` with `source_weapon_id` when present. Remove `_spawn_projectiles`, `_apply_pulse_event`, `_damage_enemy`, and `_apply_knockback`.

- [ ] **Step 6: Remove the legacy event branch and old projectile**

Delete the temporary flat-definition branch from `WeaponSystem`, delete old projectile files, and update tests/imports to `ProjectileCarrier`. Grep must return no direct player-weapon `take_damage` calls outside `HitResolver`:

```powershell
rg -n "take_damage\(" scripts/weapons scripts/systems/combat_effect_pipeline.gd
```

Expected: no matches.

- [ ] **Step 7: Run full tests and scene smoke**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
& $env:GODOT --headless --path . --quit-after 600
```

Expected: `All tests passed.` and no script/parser errors in the 600-frame smoke.

- [ ] **Step 8: Commit**

```powershell
git add data/weapons scripts/data/game_database.gd scripts/systems/weapon_system.gd scripts/core/game_loop.gd scripts/weapons scenes/game/Game.tscn scenes/weapons tests
git commit -m "feat: migrate live combat to modular weapons"
```

---

### Task 7: Add Sword Gourd, Frost Talisman, Soul Lantern And Production Art

**Files:**
- Create: `data/weapons/sword_gourd_blades.json`
- Create: `data/weapons/frost_talisman.json`
- Create: `data/weapons/soul_lantern.json`
- Modify: `data/upgrades/core_upgrades.json`
- Create: `tools/extract_green_sheet.py`
- Create: `tools/build_weapon_contact_sheet.py`
- Create: `scripts/components/status_visual.gd`
- Modify: `scenes/enemies/BasicDemon.tscn`
- Create production assets under `art/weapons/{sword_gourd,frost_talisman,soul_lantern,demon_sealing_bell}/`
- Create status assets under `art/effects/status/`
- Create green sources under `art/source_green/weapons/` and `art/source_green/effects/status/`
- Create: `art/review/modular_weapons_contact_sheet.png`
- Modify: `tests/test_game_database.gd`
- Modify: `tests/test_upgrade_system.gd`
- Modify: `tests/test_weapon_system.gd`
- Modify: `tests/test_game_scene_composition.gd`
- Modify: `tests/test_status_controller.gd`

**Interfaces:**
- Adds weapon IDs: `sword_gourd_blades`, `frost_talisman`, `soul_lantern`
- Adds upgrade IDs: `unlock_*` and `*_level` for all three

- [ ] **Step 1: Write RED content tests**

Assert exactly eight weapon definitions, two per school, all Chinese names/descriptions, every visual path exists, and every new weapon has one unlock plus one five-stack level upgrade. Assert `sword_gourd_blades` does not collide with the existing equipment ID `sword_gourd`. Assert carrier signatures: sword gourd includes `persistent/orbit` and `on_player_hit/projectile`; frost talisman includes `sector/projectile/freeze`; soul lantern includes `periodic/summon`.

- [ ] **Step 2: Run RED**

Expected: three missing weapon definitions, six missing upgrade definitions, and missing visual paths.

- [ ] **Step 3: Generate green-screen production sheets with built-in image-2**

Use one horizontal uniform-cell sheet per weapon/status family, orthographic 2D game asset style, no text, no shadows outside the asset, pure `#00FF00` background, generous separation, and no red-dominant player effects.

Exact content prompts:

```text
Sword gourd set: carved jade-and-brass sword gourd, four small cyan-white flying swords, circular orbit streak, fan-shaped retaliation sword rain, compact weapon icon; Chinese cultivation fantasy 2D mobile game, crisp silhouette, front/three-quarter views, isolated cells on pure #00FF00.

Frost talisman set: pale-blue paper frost talisman, three fan projectiles, icy hit burst, three-stage chill mark, frozen shell overlay, cyan-white thermal shatter; Chinese cultivation fantasy 2D mobile game, crisp readable silhouette, isolated cells on pure #00FF00.

Soul lantern set: dark bronze spirit lantern with teal-violet flame, six distinct homing soul flames, small summon attack burst, dissolve effect, compact weapon icon; Chinese cultivation fantasy 2D mobile game, readable at 48 pixels, isolated cells on pure #00FF00.

Seal and status set: circular gold-teal bell sound wave, seal glyph, burn stack mark, armor break crack mark, freeze mark; player-owned effects only, no solid threat red, isolated cells on pure #00FF00.
```

Save source sheets with these exact names:

```text
art/source_green/weapons/sword_gourd_sheet_green.png
art/source_green/weapons/frost_talisman_sheet_green.png
art/source_green/weapons/soul_lantern_sheet_green.png
art/source_green/effects/status/status_effects_sheet_green.png
```

- [ ] **Step 4: Implement deterministic sheet extraction, chroma-key and normalization**

Create `tools/extract_green_sheet.py` with this interface and implementation:

```python
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from chroma_key import _normalize_canvas, _remove_green


def extract_sheet(source: Path, output_dir: Path, columns: int, rows: int, names: list[str]) -> None:
    sheet = Image.open(source).convert("RGBA")
    if columns <= 0 or rows <= 0 or len(names) != columns * rows:
        raise ValueError("grid size must match the number of output names")
    output_dir.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        column = index % columns
        row = index // columns
        cell = sheet.crop((
            round(column * sheet.width / columns),
            round(row * sheet.height / rows),
            round((column + 1) * sheet.width / columns),
            round((row + 1) * sheet.height / rows),
        ))
        keyed = _remove_green(cell, 18.0, 96.0)
        normalized = _normalize_canvas(keyed, 256, 16)
        normalized.save(output_dir / f"{name}.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--columns", type=int, required=True)
    parser.add_argument("--rows", type=int, default=1)
    parser.add_argument("--names", required=True)
    args = parser.parse_args()
    extract_sheet(args.source, args.output_dir, args.columns, args.rows, args.names.split(","))


if __name__ == "__main__":
    main()
```

Run these exact commands and preserve source sheets unchanged:

```powershell
python tools/extract_green_sheet.py art/source_green/weapons/sword_gourd_sheet_green.png art/weapons/sword_gourd --columns 5 --names sword_gourd_icon,sword_gourd_body,sword_gourd_orbit_sword,sword_gourd_sword_rain,sword_gourd_hit
python tools/extract_green_sheet.py art/source_green/weapons/frost_talisman_sheet_green.png art/weapons/frost_talisman --columns 4 --names frost_talisman_icon,frost_talisman_projectile,frost_talisman_burst,thermal_shatter
python tools/extract_green_sheet.py art/source_green/weapons/soul_lantern_sheet_green.png art/weapons/soul_lantern --columns 5 --names soul_lantern_icon,soul_lantern_body,soul_flame,soul_flame_attack,soul_flame_dissolve
python tools/extract_green_sheet.py art/source_green/effects/status/status_effects_sheet_green.png art/effects/status --columns 5 --names bell_wave,burn_mark,freeze_mark,armor_break_mark,seal_mark
New-Item -ItemType Directory -Force art/weapons/demon_sealing_bell | Out-Null
Move-Item -LiteralPath art/effects/status/bell_wave.png -Destination art/weapons/demon_sealing_bell/bell_wave.png
```

Produce this exact manifest before referencing it in JSON:

```text
art/weapons/sword_gourd/sword_gourd_icon.png
art/weapons/sword_gourd/sword_gourd_body.png
art/weapons/sword_gourd/sword_gourd_orbit_sword.png
art/weapons/sword_gourd/sword_gourd_sword_rain.png
art/weapons/sword_gourd/sword_gourd_hit.png
art/weapons/frost_talisman/frost_talisman_icon.png
art/weapons/frost_talisman/frost_talisman_projectile.png
art/weapons/frost_talisman/frost_talisman_burst.png
art/weapons/frost_talisman/thermal_shatter.png
art/weapons/soul_lantern/soul_lantern_icon.png
art/weapons/soul_lantern/soul_lantern_body.png
art/weapons/soul_lantern/soul_flame.png
art/weapons/soul_lantern/soul_flame_attack.png
art/weapons/soul_lantern/soul_flame_dissolve.png
art/weapons/demon_sealing_bell/bell_wave.png
art/effects/status/burn_mark.png
art/effects/status/freeze_mark.png
art/effects/status/armor_break_mark.png
art/effects/status/seal_mark.png
```

- [ ] **Step 5: Implement the contact-sheet tool and render review output**

`build_weapon_contact_sheet.py` must accept `--background`, `--output`, and an ordered list of PNGs. It creates a 720x1280 RGB review canvas, scales the wasteland tile to fill, lays assets in four labeled rows, and draws a white checker-backed inset behind transparent effects. Run:

```python
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def checker(size: tuple[int, int], block: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, "white")
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            if (x // block + y // block) % 2:
                draw.rectangle((x, y, x + block - 1, y + block - 1), fill=(218, 218, 218, 255))
    return image


def build(background: Path, output: Path, assets: list[Path]) -> None:
    canvas = Image.open(background).convert("RGB").resize((720, 1280), Image.Resampling.LANCZOS).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    columns, rows = 5, 4
    cell_width, cell_height = 136, 286
    for index, path in enumerate(assets[: columns * rows]):
        column, row = index % columns, index // columns
        x, y = 12 + column * cell_width, 48 + row * cell_height
        panel = checker((124, 230))
        asset = Image.open(path).convert("RGBA")
        asset.thumbnail((112, 196), Image.Resampling.LANCZOS)
        panel.alpha_composite(asset, ((124 - asset.width) // 2, (210 - asset.height) // 2))
        canvas.alpha_composite(panel, (x, y))
        draw.text((x, y + 236), path.stem[:20], fill="white", stroke_width=2, stroke_fill="black")
    draw.text((12, 12), f"Modular weapons: {len(assets)} assets", fill="white", stroke_width=2, stroke_fill="black")
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--background", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("assets", type=Path, nargs="+")
    args = parser.parse_args()
    if len(args.assets) > 20:
        raise ValueError("contact sheet supports at most 20 assets")
    build(args.background, args.output, args.assets)


if __name__ == "__main__":
    main()
```

Run:

```powershell
$assets = Get-ChildItem art/weapons/sword_gourd,art/weapons/frost_talisman,art/weapons/soul_lantern,art/weapons/demon_sealing_bell,art/effects/status -Filter *.png | Sort-Object FullName | Select-Object -ExpandProperty FullName
python tools/build_weapon_contact_sheet.py --background art/environment/wasteland_ground_tile.png --output art/review/modular_weapons_contact_sheet.png $assets
python -c "from PIL import Image; im=Image.open('art/review/modular_weapons_contact_sheet.png'); assert im.size == (720,1280); assert im.getbbox() is not None"
```

Expected: a nonblank 720x1280 PNG with every requested asset visible and no overlap.

- [ ] **Step 6: Add exact weapon behaviors**

- `sword_gourd_blades`: display name `剑葫芦`; persistent orbit, base count 2/radius 82/angular speed 2.4/hit interval 0.45/damage 7; level 3 count 3; level 4 radius 104; level 5 `on_player_hit` sword rain with 4 projectiles and 4.0-second trigger cooldown.
- `frost_talisman`: periodic 1.35 seconds, sector 70 degrees/range 340, three projectiles at speed 430, damage 6, one chill application; level 3 sector 95 degrees; level 4 pierce 1; level 5 four projectiles and chill duration 3.5 seconds.
- `soul_lantern`: periodic 2.4 seconds, summon count 1/lifetime 6.0/move speed 190/attack interval 0.8/range 48, damage 5; level 3 count 2; level 4 lifetime 8.0; level 5 count 3 and attack interval 0.65.

Add Chinese upgrade names and summaries that describe behavior changes, not only percentages.

- [ ] **Step 7: Wire aggregated status visuals**

`StatusController` emits `status_changed(snapshot: Dictionary)`. `StatusVisual` displays one 32-pixel mark above the enemy and a compact stack number; priority is freeze, seal, armor break, burn. It swaps textures without creating per-stack nodes, hides when the snapshot is empty, and resets on pool release. Extend scene-composition and status tests to assert every texture exists, priority is stable, and no pooled enemy retains an old mark.

Implement the component with explicit texture exports:

```gdscript
extends Node2D
class_name StatusVisual

const PRIORITY := ["freeze", "seal", "armor_break", "burn"]

@export var freeze_texture: Texture2D
@export var seal_texture: Texture2D
@export var armor_break_texture: Texture2D
@export var burn_texture: Texture2D

@onready var icon: Sprite2D = $Icon
@onready var stack_label: Label = $StackLabel

func apply_snapshot(snapshot: Dictionary) -> void:
	var selected := ""
	for status_id in PRIORITY:
		if snapshot.has(status_id):
			selected = status_id
			break
	visible = selected != ""
	if not visible:
		stack_label.text = ""
		return
	icon.texture = _texture_for(selected)
	var stacks := int(Dictionary(snapshot[selected]).get("stacks", 1))
	stack_label.text = str(stacks) if stacks > 1 else ""

func reset_visual() -> void:
	apply_snapshot({})

func _texture_for(status_id: String) -> Texture2D:
	match status_id:
		"freeze": return freeze_texture
		"seal": return seal_texture
		"armor_break": return armor_break_texture
		"burn": return burn_texture
	return null
```

- [ ] **Step 8: Run GREEN, visual inspection, and commit**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
& $env:GODOT --headless --path . --editor --quit-after 300
git add data/weapons data/upgrades/core_upgrades.json art tools/extract_green_sheet.py tools/build_weapon_contact_sheet.py scripts/components/status_visual.gd scenes/enemies/BasicDemon.tscn tests
git commit -m "feat: add first eight production weapons"
```

Use `view_image` on `art/review/modular_weapons_contact_sheet.png`; reject green fringes, opaque boxes, unreadable 48-pixel silhouettes, red-dominant effects, or overlapping cells before committing.

---

### Task 8: Deterministic Weapon Simulation And Final Verification

**Files:**
- Create: `scripts/systems/weapon_simulator.gd`
- Create: `tools/simulate_weapons.gd`
- Create: `tests/test_weapon_simulator.gd`
- Modify: `tests/run_all_tests.gd`
- Modify: `tools/simulate_pool_churn.gd`
- Modify: `docs/superpowers/specs/2026-07-13-modular-weapons-design.md` only when measured limits require a documented correction

**Interfaces:**
- Produces: `WeaponSimulator.run(seed: int, duration: float, loadout: Array[String]) -> Dictionary`
- Report keys: `requests`, `executed`, `no_target`, `pool_queued`, `hits_by_weapon`, `statuses`, `reactions`, `carrier_counts`, `pool_peaks`, `signature`

- [ ] **Step 1: Write RED simulator tests**

Run every weapon for 30 simulated seconds and assert at least one executed request and hit. Run two identical seeds and assert reports match. Run representative four-weapon loadouts and assert all four requested carriers appear across the suite, no pool peak exceeds its limit, and each weapon signature differs in at least two dimensions among cadence, target mode, carrier, count, area, status, or persistence.

- [ ] **Step 2: Implement the deterministic simulator**

Use lightweight fake targets with positions, health and status controllers; do not instantiate rendered scenes. Advance at fixed `1.0 / 60.0` steps. Use the real validator, request builder, target selector, hit resolver and status rules. Record, do not hide, all `invalid_request` results; any invalid count fails the test.

- [ ] **Step 3: Extend pool churn**

Exercise 250 projectiles, 24 areas, 32 orbit entities, and 12 summons through acquire/release/reacquire. Final stats for every key must show `active == 0`, `created <= limit`, and `available == created`.

- [ ] **Step 4: Run complete verification**

```powershell
& $env:GODOT --headless --path . -s res://tests/run_all_tests.gd
& $env:GODOT --headless --path . -s res://tools/simulate_weapons.gd
& $env:GODOT --headless --path . -s res://tools/simulate_pool_churn.gd
& $env:GODOT --headless --path . -s res://tools/simulate_encounters.gd
& $env:GODOT --headless --path . --quit-after 600
git diff --check
```

Expected: all tests pass; eight weapons report hits; four carriers and four statuses are represented; all pools return to zero active; encounter simulation retains seven unique cards and zero triple repeats; scene smoke has no errors; diff check has no whitespace errors.

- [ ] **Step 5: Verify the spec line by line**

Check every item in `docs/superpowers/specs/2026-07-13-modular-weapons-design.md` section 12 against current files, test output, simulator output, contact sheet, and Godot scene. Record any unmet item as unfinished work rather than declaring the subproject complete.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/systems/weapon_simulator.gd tools/simulate_weapons.gd tools/simulate_pool_churn.gd tests/test_weapon_simulator.gd tests/run_all_tests.gd
git commit -m "test: verify modular weapon combat"
git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c http.version=HTTP/1.1 -c core.compression=9 push --progress origin main
```

Expected: `main` and `origin/main` point at the same final commit and `git status --short --branch` shows no worktree changes.
