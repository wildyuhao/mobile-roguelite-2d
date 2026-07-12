extends RefCounted
class_name GameDatabase

const WeaponDefinitionValidatorScript = preload(
	"res://scripts/weapons/weapon_definition_validator.gd"
)

var weapons: Dictionary = {}
var enemies: Dictionary = {}
var upgrades: Array[Dictionary] = []
var equipment: Array[Dictionary] = []
var wave_events: Array[Dictionary] = []
var encounters: Array[Dictionary] = []
var formations: Dictionary = {}
var errors: Array[String] = []

func load_all() -> bool:
	errors.clear()
	weapons = _load_directory_as_id_map("res://data/weapons")
	errors.append_array(
		WeaponDefinitionValidatorScript.new().validate_catalog(weapons)
	)
	enemies = _load_directory_as_id_map("res://data/enemies")
	formations = _array_to_id_map(
		_load_json_array("res://data/encounters/formations.json"),
		"formation"
	)
	encounters = _load_json_array("res://data/encounters/first_chapter.json")
	upgrades = _load_json_array("res://data/upgrades/core_upgrades.json")
	equipment = _load_json_array("res://data/equipment/starter_equipment.json")
	wave_events = _load_json_array("res://data/waves/first_run.json")
	_validate_encounters()
	return errors.is_empty()

func has_weapon(id: String) -> bool:
	return weapons.has(id)

func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

func get_weapons() -> Dictionary:
	return weapons

func has_enemy(id: String) -> bool:
	return enemies.has(id)

func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func get_enemies() -> Dictionary:
	return enemies

func get_upgrades() -> Array[Dictionary]:
	return upgrades

func get_equipment() -> Array[Dictionary]:
	return equipment

func get_wave_events() -> Array[Dictionary]:
	return wave_events

func get_encounters() -> Array[Dictionary]:
	return encounters

func get_formations() -> Dictionary:
	return formations

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
	var data = _load_json(path)
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Expected JSON object at %s" % path)
		return {}
	return data

func _load_json_array(path: String) -> Array[Dictionary]:
	var data = _load_json(path)
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
	var parsed = JSON.parse_string(text)
	if parsed == null:
		errors.append("Invalid JSON: %s" % path)
	return parsed

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
			errors.append(
			"Encounter %s references missing formation %s" % [encounter_id, formation_id]
		)
		if int(encounter.get("weight", 0)) <= 0 or int(encounter.get("pressure_cost", 0)) <= 0:
			errors.append("Encounter %s has invalid weight or pressure" % encounter_id)
		var groups: Array = encounter.get("groups", [])
		if groups.is_empty():
			errors.append("Encounter %s has no groups" % encounter_id)
		for group in groups:
			var enemy_id := String(group.get("enemy_id", ""))
			if not enemies.has(enemy_id) or int(group.get("count", 0)) <= 0:
				errors.append(
				"Encounter %s has invalid enemy group %s" % [encounter_id, enemy_id]
			)
