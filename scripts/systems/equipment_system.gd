extends RefCounted
class_name EquipmentSystem

var equipment_by_id: Dictionary = {}
var equipped_ids: Array[String] = []
var equipment_levels: Dictionary = {}
const BASE_UPGRADE_COST := 10

func configure(equipment_definitions: Array) -> void:
	equipment_by_id.clear()
	for definition in equipment_definitions:
		if typeof(definition) == TYPE_DICTIONARY and definition.has("id"):
			equipment_by_id[definition["id"]] = definition

func equip(ids: Array) -> void:
	equipped_ids.clear()
	for id in ids:
		if equipment_by_id.has(id):
			equipped_ids.append(id)

func set_equipment_levels(levels: Dictionary) -> void:
	equipment_levels = levels.duplicate(true)

func get_total_modifiers() -> Dictionary:
	var totals: Dictionary = {}
	for id in equipped_ids:
		var definition: Dictionary = equipment_by_id[id]
		var modifiers: Dictionary = definition.get("stat_modifiers", {})
		var level: int = max(1, int(equipment_levels.get(id, 1)))
		for stat in modifiers.keys():
			totals[stat] = float(totals.get(stat, 0.0)) + float(modifiers[stat]) * level

	return _normalize_number_types(totals)

func get_starting_weapon_ids() -> Array[String]:
	var weapon_ids: Array[String] = []
	for id in equipped_ids:
		var definition: Dictionary = equipment_by_id[id]
		if definition.has("starting_weapon_id"):
			weapon_ids.append(definition["starting_weapon_id"])
	return weapon_ids

func get_upgrade_cost(equipment_id: String, save_data: Dictionary) -> int:
	var levels: Dictionary = save_data.get("equipment_levels", {})
	var current_level: int = max(1, int(levels.get(equipment_id, 1)))
	return BASE_UPGRADE_COST * current_level

func can_upgrade(equipment_id: String, save_data: Dictionary) -> bool:
	if not equipment_by_id.has(equipment_id):
		return false
	if not save_data.get("unlocked_equipment", []).has(equipment_id):
		return false
	return int(save_data.get("materials", 0)) >= get_upgrade_cost(equipment_id, save_data)

func upgrade_equipment_in_save(equipment_id: String, save_data: Dictionary) -> Dictionary:
	if not equipment_by_id.has(equipment_id):
		return _build_upgrade_result(false, "unknown_equipment", 0, 0)
	if not save_data.get("unlocked_equipment", []).has(equipment_id):
		return _build_upgrade_result(false, "locked_equipment", 0, 0)

	var cost: int = get_upgrade_cost(equipment_id, save_data)
	if int(save_data.get("materials", 0)) < cost:
		return _build_upgrade_result(false, "insufficient_materials", cost, int(save_data.get("equipment_levels", {}).get(equipment_id, 1)))

	if not save_data.has("equipment_levels") or typeof(save_data["equipment_levels"]) != TYPE_DICTIONARY:
		save_data["equipment_levels"] = {}

	var levels: Dictionary = save_data["equipment_levels"]
	var next_level: int = max(1, int(levels.get(equipment_id, 1))) + 1
	levels[equipment_id] = next_level
	save_data["materials"] = int(save_data.get("materials", 0)) - cost
	return _build_upgrade_result(true, "", cost, next_level)

func _normalize_number_types(values: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in values.keys():
		var value := float(values[key])
		normalized[key] = int(value) if is_equal_approx(value, round(value)) else value
	return normalized

func _build_upgrade_result(success: bool, reason: String, cost: int, level: int) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"cost": cost,
		"level": level,
	}
