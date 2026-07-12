extends Node
class_name StatusController

signal status_damage_requested(target: Node, packet: Dictionary)
signal status_changed(snapshot: Dictionary)

const BURN_TICK_INTERVAL := 0.5
const BURN_DAMAGE_PER_STACK := 2
const BURN_MAX_STACKS := 3
const FREEZE_STACKS_REQUIRED := 3
const FREEZE_DURATION := 1.25
const FREEZE_IMMUNITY_DURATION := 1.5
const THERMAL_SHATTER_DAMAGE := 18
const THERMAL_REACTION_COOLDOWN := 0.75

var statuses: Dictionary = {}
var is_boss: bool = false
var freeze_immunity_remaining: float = 0.0
var thermal_reaction_remaining: float = 0.0

func configure(new_is_boss: bool = false) -> void:
	is_boss = new_is_boss
	clear_all()

func apply_status(payload: Dictionary, source: Dictionary = {}) -> Dictionary:
	var status_id := String(payload.get("id", ""))
	var result := {
		"applied": false,
		"status_id": status_id,
		"thermal_shatter_damage": 0,
		"consumed_statuses": [],
	}
	if _target_is_dead() or not status_id in ["burn", "freeze", "armor_break", "seal"]:
		return result

	if status_id == "burn" and is_frozen() and _can_trigger_thermal_reaction():
		_trigger_thermal_reaction(result)
		result["applied"] = true
		status_changed.emit(get_snapshot())
		return result

	match status_id:
		"burn":
			_apply_burn(payload, source)
		"freeze":
			_apply_freeze(payload, source)
		"armor_break", "seal":
			_apply_single_status(status_id, payload, source)

	result["applied"] = true
	if (
		status_id == "freeze"
		and is_frozen()
		and statuses.has("burn")
		and _can_trigger_thermal_reaction()
	):
		_trigger_thermal_reaction(result)
	status_changed.emit(get_snapshot())
	return result

func tick_statuses(delta: float) -> Array[Dictionary]:
	var safe_delta := maxf(0.0, delta)
	thermal_reaction_remaining = maxf(0.0, thermal_reaction_remaining - safe_delta)
	freeze_immunity_remaining = maxf(0.0, freeze_immunity_remaining - safe_delta)
	var packets: Array[Dictionary] = []
	var snapshot_changed := false

	for status_id_value in statuses.keys():
		var status_id := String(status_id_value)
		var state: Dictionary = statuses[status_id]
		state["remaining"] = float(state.get("remaining", 0.0)) - safe_delta
		if status_id == "burn":
			state["tick_remaining"] = float(
				state.get("tick_remaining", BURN_TICK_INTERVAL)
			) - safe_delta
			while (
				float(state["tick_remaining"]) <= 0.0
				and float(state.get("remaining", 0.0)) >= 0.0
			):
				var packet := _build_burn_packet(state)
				packets.append(packet)
				status_damage_requested.emit(get_parent(), packet)
				state["tick_remaining"] = float(state["tick_remaining"]) + BURN_TICK_INTERVAL

		if float(state.get("remaining", 0.0)) <= 0.0:
			if status_id == "freeze" and bool(state.get("frozen", false)):
				freeze_immunity_remaining = FREEZE_IMMUNITY_DURATION
			statuses.erase(status_id)
			snapshot_changed = true

	if snapshot_changed:
		status_changed.emit(get_snapshot())
	return packets

func get_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for status_id in statuses.keys():
		var state: Dictionary = statuses[status_id]
		snapshot[status_id] = {
			"stacks": int(state.get("stacks", 1)),
			"remaining": maxf(0.0, float(state.get("remaining", 0.0))),
			"frozen": bool(state.get("frozen", false)),
		}
	return snapshot

func get_damage_multiplier(tags: Array) -> float:
	if (
		statuses.has("armor_break")
		and tags.has("direct")
		and not tags.has("status_damage")
	):
		return 1.15
	return 1.0

func get_movement_multiplier() -> float:
	return 0.0 if is_frozen() and not is_boss else 1.0

func get_action_time_scale() -> float:
	if not is_frozen():
		return 1.0
	return 0.35 if is_boss else 0.0

func can_start_special() -> bool:
	return not statuses.has("seal") and not is_frozen()

func is_frozen() -> bool:
	if not statuses.has("freeze"):
		return false
	return bool(Dictionary(statuses["freeze"]).get("frozen", false))

func clear_all() -> void:
	statuses.clear()
	freeze_immunity_remaining = 0.0
	thermal_reaction_remaining = 0.0
	status_changed.emit({})

func _apply_burn(payload: Dictionary, source: Dictionary) -> void:
	var state: Dictionary = statuses.get("burn", {
		"stacks": 0,
		"remaining": 0.0,
		"tick_remaining": BURN_TICK_INTERVAL,
		"source": {},
	})
	state["stacks"] = mini(
		BURN_MAX_STACKS,
		int(state.get("stacks", 0)) + maxi(1, int(payload.get("stacks", 1)))
	)
	state["remaining"] = maxf(
		float(state.get("remaining", 0.0)),
		float(payload.get("duration", 0.0))
	)
	state["source"] = source.duplicate(true)
	statuses["burn"] = state

func _apply_freeze(payload: Dictionary, source: Dictionary) -> void:
	var state: Dictionary = statuses.get("freeze", {
		"stacks": 0,
		"remaining": 0.0,
		"frozen": false,
		"source": {},
	})
	var added_stacks := maxi(1, int(payload.get("stacks", 1)))
	if freeze_immunity_remaining > 0.0:
		state["stacks"] = mini(1, int(state.get("stacks", 0)) + added_stacks)
		state["frozen"] = false
	else:
		state["stacks"] = mini(
			FREEZE_STACKS_REQUIRED,
			int(state.get("stacks", 0)) + added_stacks
		)
		if int(state["stacks"]) >= FREEZE_STACKS_REQUIRED:
			state["frozen"] = true
	state["remaining"] = (
		FREEZE_DURATION
		if bool(state.get("frozen", false))
		else maxf(
			float(state.get("remaining", 0.0)),
			float(payload.get("duration", 0.0))
		)
	)
	state["source"] = source.duplicate(true)
	statuses["freeze"] = state

func _apply_single_status(
	status_id: String,
	payload: Dictionary,
	source: Dictionary
) -> void:
	var state: Dictionary = statuses.get(status_id, {
		"stacks": 1,
		"remaining": 0.0,
		"source": {},
	})
	state["stacks"] = 1
	state["remaining"] = maxf(
		float(state.get("remaining", 0.0)),
		float(payload.get("duration", 0.0))
	)
	state["source"] = source.duplicate(true)
	statuses[status_id] = state

func _can_trigger_thermal_reaction() -> bool:
	return thermal_reaction_remaining <= 0.0

func _trigger_thermal_reaction(result: Dictionary) -> void:
	var consumed: Array[String] = []
	for status_id in ["burn", "freeze"]:
		if statuses.has(status_id):
			consumed.append(status_id)
			statuses.erase(status_id)
	result["thermal_shatter_damage"] = THERMAL_SHATTER_DAMAGE
	result["consumed_statuses"] = consumed
	thermal_reaction_remaining = THERMAL_REACTION_COOLDOWN

func _build_burn_packet(state: Dictionary) -> Dictionary:
	var source: Dictionary = state.get("source", {})
	return {
		"source_weapon_id": String(source.get("weapon_id", "")),
		"source_instance_id": int(source.get("source_instance_id", 0)),
		"base_damage": BURN_DAMAGE_PER_STACK * int(state.get("stacks", 1)),
		"damage_tags": ["status_damage", "burn"],
		"knockback": 0.0,
		"hit_position": Vector2.ZERO,
		"status_payloads": [],
		"hit_effect_id": "burn_tick",
	}

func _target_is_dead() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var health := parent.get_node_or_null("HealthComponent")
	return health != null and health.has_method("is_dead") and bool(health.is_dead())
