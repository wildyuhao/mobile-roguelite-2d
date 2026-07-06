extends Node
class_name WeaponSystem

var weapons: Dictionary = {}
var stat_modifiers: Dictionary = {}

func set_stat_modifiers(modifiers: Dictionary) -> void:
	stat_modifiers = modifiers.duplicate(true)

func add_weapon(definition: Dictionary) -> void:
	var id: String = definition["id"]
	weapons[id] = {
		"definition": definition.duplicate(true),
		"level": 1,
		"cooldown_remaining": float(definition.get("cooldown", 1.0)),
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
			state["cooldown_remaining"] = float(state["cooldown_remaining"]) + get_weapon_cooldown(id)
	return events

func get_weapon_damage(id: String) -> int:
	var value := int(_get_base_definition_value(id, "base_damage", 1))
	for modifier in _get_active_level_modifiers(id):
		if modifier.has("base_damage"):
			value = int(modifier["base_damage"])
	return value

func get_weapon_cooldown(id: String) -> float:
	var value := float(_get_modified_definition_value(id, "cooldown", 1.0))
	var multiplier := 1.0 + float(stat_modifiers.get("weapon_cooldown_multiplier", 0.0))
	return max(0.05, value * multiplier)

func get_weapon_pierce(id: String) -> int:
	return int(_get_modified_definition_value(id, "pierce", 0))

func get_weapon_range(id: String) -> int:
	return int(_get_modified_definition_value(id, "range", 320))

func get_weapon_area_size(id: String) -> int:
	return int(_get_modified_definition_value(id, "area_size", 0))

func get_weapon_knockback(id: String) -> int:
	return int(_get_modified_definition_value(id, "knockback", 0))

func get_weapon_stun_chance(id: String) -> float:
	return float(_get_modified_definition_value(id, "stun_chance", 0.0))

func _build_fire_event(id: String, state: Dictionary) -> Dictionary:
	var definition: Dictionary = state["definition"]
	return {
		"weapon_id": id,
		"weapon_type": definition.get("type", "projectile"),
		"damage": get_weapon_damage(id),
		"range": get_weapon_range(id),
		"projectile_speed": int(definition.get("projectile_speed", 480)),
		"projectile_count": _get_projectile_count(id),
		"pierce": get_weapon_pierce(id),
		"area_size": get_weapon_area_size(id),
		"knockback": get_weapon_knockback(id),
		"stun_chance": get_weapon_stun_chance(id),
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

func _get_modified_definition_value(id: String, key: String, fallback: Variant) -> Variant:
	var value = _get_base_definition_value(id, key, fallback)
	for modifier in _get_active_level_modifiers(id):
		if modifier.has(key):
			value = modifier[key]
	return value

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
