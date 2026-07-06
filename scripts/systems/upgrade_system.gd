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
		choices.append(_with_effect_summary(available[index]))
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
	elif upgrade.get("kind", "") == "weapon_unlock":
		var weapon_id: String = upgrade.get("weapon_id", "")
		var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
		if weapon_id != "" and not owned_weapons.has(weapon_id):
			owned_weapons[weapon_id] = 1
		runtime_state["owned_weapons"] = owned_weapons

func get_stat_modifiers(runtime_state: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})

	for upgrade in upgrades:
		if upgrade.get("kind", "") != "stat":
			continue
		var id: String = upgrade.get("id", "")
		var stack_count := int(stacks.get(id, 0))
		if stack_count <= 0:
			continue
		var stat: String = upgrade.get("stat", "")
		if stat == "":
			continue
		totals[stat] = float(totals.get(stat, 0.0)) + float(upgrade.get("value", 0.0)) * stack_count

	return _normalize_number_types(totals)

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
		elif upgrade.get("kind", "") == "weapon_unlock":
			var weapon_id: String = upgrade.get("weapon_id", "")
			if owned_weapons.has(weapon_id):
				continue

		result.append(upgrade)

	return result

func _normalize_number_types(values: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in values.keys():
		var value := float(values[key])
		normalized[key] = int(value) if is_equal_approx(value, round(value)) else value
	return normalized

func _with_effect_summary(upgrade: Dictionary) -> Dictionary:
	var result := upgrade.duplicate(true)
	var summary := _build_effect_summary(result)
	if summary != "":
		result["effect_summary"] = summary
	return result

func _build_effect_summary(upgrade: Dictionary) -> String:
	var kind := String(upgrade.get("kind", ""))
	if kind == "weapon_level":
		return "Weapon Lv +1"
	if kind == "weapon_unlock":
		return "Unlock Weapon"
	if kind != "stat":
		return ""

	var stat := String(upgrade.get("stat", ""))
	var value := float(upgrade.get("value", 0.0))
	match stat:
		"weapon_damage_multiplier":
			return "Damage %s" % _format_signed_value(value, true)
		"weapon_cooldown_multiplier":
			return "CD %s" % _format_signed_value(value, true)
		"pickup_radius":
			return "Pickup %s" % _format_signed_value(value, false)
		"move_speed":
			return "Speed %s" % _format_signed_value(value, false)
		"max_health":
			return "HP %s" % _format_signed_value(value, false)
		"material_gain":
			return "Mat %s" % _format_signed_value(value, true)
		"control_duration":
			return "Control %s" % _format_signed_value(value, true)
	return ""

func _format_signed_value(value: float, as_percent: bool) -> String:
	var scale := 100.0 if as_percent else 1.0
	var amount := int(round(value * scale))
	var prefix := "+" if amount > 0 else ""
	var suffix := "%" if as_percent else ""
	return "%s%d%s" % [prefix, amount, suffix]
