extends Node
class_name WeaponSystem

const WeaponRequestBuilderScript = preload("res://scripts/weapons/weapon_request_builder.gd")
const MAX_WEAPON_SLOTS := 4

@export var max_weapon_slots: int = MAX_WEAPON_SLOTS

var weapons: Dictionary = {}
var stat_modifiers: Dictionary = {}
var request_builder = WeaponRequestBuilderScript.new()
var next_request_id: int = 1
var pending_request_effects: Dictionary = {}

func set_stat_modifiers(modifiers: Dictionary) -> void:
	stat_modifiers = modifiers.duplicate(true)

func can_add_weapon(definition: Dictionary) -> bool:
	var id := String(definition.get("id", ""))
	if id == "" or weapons.has(id) or int(definition.get("version", 0)) != 1:
		return false
	return weapons.size() < clampi(max_weapon_slots, 1, MAX_WEAPON_SLOTS)

func add_weapon(definition: Dictionary) -> bool:
	if not can_add_weapon(definition):
		return false
	var id := String(definition.get("id", ""))
	var state := {
		"definition": definition.duplicate(true),
		"level": 1,
	}
	weapons[id] = state
	_refresh_modular_effects(id, state, true)
	return true

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
	var previous_level := int(state["level"])
	state["level"] = min(max_level, previous_level + 1)
	if int(state["level"]) != previous_level:
		_refresh_modular_effects(id, state, false)

func tick(delta: float) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	for id in weapons.keys():
		requests.append_array(
			_tick_modular_weapon(String(id), weapons[id], delta)
		)
	return requests

func notify_trigger(trigger_id: String, payload: Dictionary = {}) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	for weapon_id_value in weapons.keys():
		var weapon_id := String(weapon_id_value)
		var state: Dictionary = weapons[weapon_id]
		var effect_states: Dictionary = state.get("effect_states", {})
		for effect in _get_resolved_effects(state):
			var trigger: Dictionary = effect.get("trigger", {})
			if String(trigger.get("id", "")) != trigger_id:
				continue
			var effect_id := String(effect.get("effect_id", ""))
			var effect_state: Dictionary = effect_states.get(effect_id, {})
			if float(effect_state.get("remaining", 0.0)) > 0.0:
				continue
			requests.append(_make_request(weapon_id, effect, payload))
			effect_state["remaining"] = _get_trigger_cooldown(trigger)
	return requests

func acknowledge_request(request_id: int, result: String) -> void:
	if not pending_request_effects.has(request_id):
		return
	var request_reference: Dictionary = pending_request_effects[request_id]
	pending_request_effects.erase(request_id)
	if result != "no_target":
		return
	var weapon_id := String(request_reference.get("weapon_id", ""))
	var effect_id := String(request_reference.get("effect_id", ""))
	if not weapons.has(weapon_id):
		return
	var state: Dictionary = weapons[weapon_id]
	var effect_states: Dictionary = state.get("effect_states", {})
	if not effect_states.has(effect_id):
		return
	var effect_state: Dictionary = effect_states[effect_id]
	effect_state["remaining"] = minf(float(effect_state.get("remaining", 0.1)), 0.1)

func get_weapon_damage(id: String) -> int:
	var effect := _get_primary_effect(id)
	var hit: Dictionary = effect.get("hit", {})
	var value := int(hit.get("damage", 1))
	var multiplier := 1.0 + float(stat_modifiers.get("weapon_damage_multiplier", 0.0))
	return maxi(1, int(round(value * multiplier)))

func get_weapon_cooldown(id: String) -> float:
	var effect := _get_primary_effect(id)
	if effect.is_empty():
		return 1.0
	return _get_trigger_cooldown(effect.get("trigger", {}))

func get_weapon_pierce(id: String) -> int:
	var effect := _get_primary_effect(id)
	return int(Dictionary(effect.get("carrier", {})).get("pierce", 0))

func get_weapon_range(id: String) -> int:
	var effect := _get_primary_effect(id)
	return int(Dictionary(effect.get("target", {})).get("range", 320))

func get_weapon_area_size(id: String) -> int:
	var effect := _get_primary_effect(id)
	var hit: Dictionary = effect.get("hit", {})
	if hit.has("splash_radius"):
		return int(hit.get("splash_radius", 0))
	return int(Dictionary(effect.get("carrier", {})).get("radius", 0))

func get_weapon_knockback(id: String) -> int:
	var effect := _get_primary_effect(id)
	return int(Dictionary(effect.get("hit", {})).get("knockback", 0))

func _get_primary_effect(id: String) -> Dictionary:
	if not weapons.has(id):
		return {}
	var effects := _get_resolved_effects(weapons[id])
	return effects[0] if not effects.is_empty() else {}

func _refresh_modular_effects(id: String, state: Dictionary, is_new: bool) -> void:
	var old_states: Dictionary = state.get("effect_states", {})
	var effects := request_builder.resolve_effects(
		state["definition"],
		int(state.get("level", 1))
	)
	var next_states: Dictionary = {}
	for effect in effects:
		var effect_id := String(effect.get("effect_id", ""))
		var trigger: Dictionary = effect.get("trigger", {})
		var trigger_id := String(trigger.get("id", ""))
		var effect_state: Dictionary = old_states.get(effect_id, {}).duplicate(true)
		if effect_state.is_empty():
			effect_state["remaining"] = (
				_get_trigger_cooldown(trigger)
				if trigger_id == "periodic"
				else 0.0
			)
		elif not is_new and trigger_id != "persistent":
			effect_state["remaining"] = minf(
				float(effect_state.get("remaining", 0.0)),
				_get_trigger_cooldown(trigger)
			)
		if trigger_id == "persistent":
			effect_state["persistent_pending"] = true
		elif is_new:
			effect_state["persistent_pending"] = false
		next_states[effect_id] = effect_state
	state["resolved_effects"] = effects
	state["effect_states"] = next_states
	weapons[id] = state

func _tick_modular_weapon(
	weapon_id: String,
	state: Dictionary,
	delta: float
) -> Array[Dictionary]:
	var requests: Array[Dictionary] = []
	var effect_states: Dictionary = state.get("effect_states", {})
	for effect in _get_resolved_effects(state):
		var effect_id := String(effect.get("effect_id", ""))
		var trigger: Dictionary = effect.get("trigger", {})
		var trigger_id := String(trigger.get("id", ""))
		var effect_state: Dictionary = effect_states.get(effect_id, {})
		if trigger_id == "persistent":
			if bool(effect_state.get("persistent_pending", false)):
				requests.append(_make_request(weapon_id, effect))
				effect_state["persistent_pending"] = false
			continue

		effect_state["remaining"] = maxf(
			0.0,
			float(effect_state.get("remaining", 0.0)) - maxf(0.0, delta)
		)
		if trigger_id == "periodic" and float(effect_state["remaining"]) <= 0.0:
			requests.append(_make_request(weapon_id, effect))
			effect_state["remaining"] = _get_trigger_cooldown(trigger)
	return requests

func _get_resolved_effects(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect in state.get("resolved_effects", []):
		if typeof(effect) == TYPE_DICTIONARY:
			result.append(effect)
	return result

func _make_request(
	weapon_id: String,
	effect: Dictionary,
	payload: Dictionary = {}
) -> Dictionary:
	var request_id := next_request_id
	next_request_id += 1
	pending_request_effects[request_id] = {
		"weapon_id": weapon_id,
		"effect_id": String(effect.get("effect_id", "")),
	}
	var trigger: Dictionary = effect.get("trigger", {}).duplicate(true)
	if trigger.has("cooldown"):
		trigger["cooldown"] = _get_trigger_cooldown(trigger)
	if trigger.has("event_cooldown"):
		trigger["event_cooldown"] = _get_trigger_cooldown(trigger)
	var hit: Dictionary = effect.get("hit", {}).duplicate(true)
	var damage_multiplier := 1.0 + float(stat_modifiers.get("weapon_damage_multiplier", 0.0))
	hit["damage"] = maxi(
		0,
		int(round(int(hit.get("damage", 0)) * damage_multiplier))
	)
	var definition: Dictionary = weapons[weapon_id]["definition"]
	var visual: Dictionary = Dictionary(definition.get("visual", {})).duplicate(true)
	for visual_key in Dictionary(effect.get("visual", {})).keys():
		visual[visual_key] = effect["visual"][visual_key]
	return {
		"request_id": request_id,
		"weapon_id": weapon_id,
		"effect_id": String(effect.get("effect_id", "")),
		"trigger": trigger,
		"target": Dictionary(effect.get("target", {})).duplicate(true),
		"carrier": Dictionary(effect.get("carrier", {})).duplicate(true),
		"hit": hit,
		"visual": visual,
		"trigger_payload": payload.duplicate(true),
	}

func _get_trigger_cooldown(trigger: Dictionary) -> float:
	var key := "event_cooldown" if trigger.has("event_cooldown") else "cooldown"
	var base_cooldown := float(trigger.get(key, 0.0))
	var multiplier := 1.0 + float(stat_modifiers.get("weapon_cooldown_multiplier", 0.0))
	return maxf(0.05, base_cooldown * multiplier)
