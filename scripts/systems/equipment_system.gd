extends RefCounted
class_name EquipmentSystem

var equipment_by_id: Dictionary = {}
var equipped_ids: Array[String] = []
var equipment_levels: Dictionary = {}

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

func _normalize_number_types(values: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in values.keys():
		var value := float(values[key])
		normalized[key] = int(value) if is_equal_approx(value, round(value)) else value
	return normalized
