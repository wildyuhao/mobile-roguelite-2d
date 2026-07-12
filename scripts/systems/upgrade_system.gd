extends RefCounted
class_name UpgradeSystem

const MAX_WEAPON_SLOTS := 4
const OPENING_WEAPON_TARGET := 2

var upgrades: Array[Dictionary] = []

func configure(new_upgrades: Array[Dictionary]) -> void:
	upgrades = new_upgrades.duplicate(true)

func get_choices(runtime_state: Dictionary, count: int = 3, seed_value: int = 0) -> Array[Dictionary]:
	var available := _get_available_upgrades(runtime_state)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()

	var choices: Array[Dictionary] = []
	var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
	var opening_target := mini(
		OPENING_WEAPON_TARGET,
		_get_max_weapon_slots(runtime_state)
	)
	if count > 0 and owned_weapons.size() < opening_target:
		var unlocks: Array[Dictionary] = []
		for upgrade in available:
			if String(upgrade.get("kind", "")) == "weapon_unlock":
				unlocks.append(upgrade)
		if not unlocks.is_empty():
			var unlock_index := rng.randi_range(0, unlocks.size() - 1)
			var unlock_choice: Dictionary = unlocks[unlock_index]
			choices.append(_with_effect_summary(unlock_choice))
			_remove_upgrade_by_id(available, String(unlock_choice.get("id", "")))

	while not available.is_empty() and choices.size() < count:
		var index := rng.randi_range(0, available.size() - 1)
		choices.append(_with_effect_summary(available[index]))
		available.remove_at(index)
	return choices

func apply_upgrade(runtime_state: Dictionary, upgrade: Dictionary) -> bool:
	var id := String(upgrade.get("id", ""))
	if id == "":
		return false
	var kind := String(upgrade.get("kind", ""))
	var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
	var weapon_id := String(upgrade.get("weapon_id", ""))
	if kind == "weapon_level" and (weapon_id == "" or not owned_weapons.has(weapon_id)):
		return false
	if kind == "weapon_unlock":
		if (
			weapon_id == ""
			or owned_weapons.has(weapon_id)
			or owned_weapons.size() >= _get_max_weapon_slots(runtime_state)
		):
			return false

	if not runtime_state.has("upgrade_stacks"):
		runtime_state["upgrade_stacks"] = {}

	var stacks: Dictionary = runtime_state["upgrade_stacks"]
	if int(stacks.get(id, 0)) >= int(upgrade.get("max_stacks", 1)):
		return false
	stacks[id] = int(stacks.get(id, 0)) + 1

	if kind == "weapon_level":
		owned_weapons[weapon_id] = int(owned_weapons.get(weapon_id, 1)) + 1
		runtime_state["owned_weapons"] = owned_weapons
	elif kind == "weapon_unlock":
		owned_weapons[weapon_id] = 1
		runtime_state["owned_weapons"] = owned_weapons
	return true

func get_stat_modifiers(runtime_state: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})

	for upgrade in upgrades:
		var id: String = upgrade.get("id", "")
		var stack_count := int(stacks.get(id, 0))
		if stack_count <= 0:
			continue
		var kind := String(upgrade.get("kind", ""))
		if kind == "stat":
			var stat: String = upgrade.get("stat", "")
			if stat != "":
				totals[stat] = float(totals.get(stat, 0.0)) + float(upgrade.get("value", 0.0)) * stack_count
		elif kind == "stat_bundle":
			var modifiers: Dictionary = upgrade.get("stat_modifiers", {})
			for stat in modifiers.keys():
				totals[stat] = float(totals.get(stat, 0.0)) + float(modifiers[stat]) * stack_count

	return _normalize_number_types(totals)

func _get_available_upgrades(runtime_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})
	var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
	var max_weapon_slots := _get_max_weapon_slots(runtime_state)
	var seen_ids := {}

	for upgrade in upgrades:
		var id: String = upgrade["id"]
		if seen_ids.has(id):
			continue
		seen_ids[id] = true
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
			if owned_weapons.has(weapon_id) or owned_weapons.size() >= max_weapon_slots:
				continue

		result.append(upgrade)

	return result

func _get_max_weapon_slots(runtime_state: Dictionary) -> int:
	return clampi(int(runtime_state.get("max_weapon_slots", MAX_WEAPON_SLOTS)), 1, MAX_WEAPON_SLOTS)

func _remove_upgrade_by_id(available: Array[Dictionary], upgrade_id: String) -> void:
	for index in range(available.size()):
		if String(available[index].get("id", "")) == upgrade_id:
			available.remove_at(index)
			return

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
		return "武器等级 +1"
	if kind == "weapon_unlock":
		return "解锁武器"
	if kind == "stat_bundle":
		var parts: Array[String] = []
		var modifiers: Dictionary = upgrade.get("stat_modifiers", {})
		for stat in modifiers.keys():
			var part := _build_stat_effect(String(stat), float(modifiers[stat]))
			if part != "":
				parts.append(part)
		return _join_effect_parts(parts)
	if kind == "stat":
		return _build_stat_effect(String(upgrade.get("stat", "")), float(upgrade.get("value", 0.0)))
	return ""

func _build_stat_effect(stat: String, value: float) -> String:
	match stat:
		"weapon_damage_multiplier":
			return "伤害 %s" % _format_signed_value(value, true)
		"weapon_cooldown_multiplier":
			return "冷却 %s" % _format_signed_value(value, true)
		"pickup_radius":
			return "拾取范围 %s" % _format_signed_value(value, false)
		"move_speed":
			return "移速 %s" % _format_signed_value(value, false)
		"max_health":
			return "生命 %s" % _format_signed_value(value, false)
		"material_gain":
			return "灵石收益 %s" % _format_signed_value(value, true)
		"control_duration":
			return "控制时长 %s" % _format_signed_value(value, true)
	return ""

func _join_effect_parts(parts: Array[String]) -> String:
	var result := ""
	for part in parts:
		if result != "":
			result += "，"
		result += part
	return result

func _format_signed_value(value: float, as_percent: bool) -> String:
	var scale := 100.0 if as_percent else 1.0
	var amount := int(round(value * scale))
	var prefix := "+" if amount > 0 else ""
	var suffix := "%" if as_percent else ""
	return "%s%d%s" % [prefix, amount, suffix]
