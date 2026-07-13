extends RefCounted
class_name SaveSystem

const CURRENT_VERSION := 2
const DEFAULT_CHARACTER_ID := "mechanism_walker"
const DEFAULT_MISSION_ID := "red_wastes_survival"
const DEFAULT_CHAPTER_ID := "red_wastes"
const DEFAULT_UNLOCKED_EQUIPMENT := ["talisman_robe", "cloudstep_boots", "bronze_gear_core", "jade_compass", "sword_gourd"]
const CharacterProgression = preload("res://scripts/systems/character_progression.gd")

var save_path: String
var known_mission_ids: Dictionary = {DEFAULT_MISSION_ID: true}
var known_character_ids: Dictionary = {DEFAULT_CHARACTER_ID: true}
var known_chapter_ids: Dictionary = {DEFAULT_CHAPTER_ID: true}

func _init(new_save_path: String = "user://save.json") -> void:
	save_path = new_save_path

func configure_content_ids(mission_ids: Array[String], character_ids: Array[String], chapter_ids: Array[String]) -> void:
	known_mission_ids = _make_id_set(mission_ids)
	known_character_ids = _make_id_set(character_ids)
	known_chapter_ids = _make_id_set(chapter_ids)
	known_mission_ids[DEFAULT_MISSION_ID] = true
	known_character_ids[DEFAULT_CHARACTER_ID] = true
	known_chapter_ids[DEFAULT_CHAPTER_ID] = true

func create_default_save() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"materials": 0,
		"equipment_levels": {},
		"unlocked_equipment": DEFAULT_UNLOCKED_EQUIPMENT.duplicate(),
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 0.8
		},
		"campaign": {
			"completed_missions": {},
			"unlocked_missions": [DEFAULT_MISSION_ID],
			"chapter_marks": {DEFAULT_CHAPTER_ID: 0},
			"selected_mission_id": DEFAULT_MISSION_ID,
		},
		"characters": {
			"unlocked_ids": [DEFAULT_CHARACTER_ID],
			"mastery_levels": {DEFAULT_CHARACTER_ID: 1},
			"mastery_experience": {DEFAULT_CHARACTER_ID: 0},
			"selected_id": DEFAULT_CHARACTER_ID,
			"starting_loadouts": {},
		},
		"codex": {"unlocked_entries": []},
		"resources": {"demon_cores": 0},
	}

func load_game() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return create_default_save()

	var text := FileAccess.get_file_as_string(save_path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return create_default_save()
	return _normalize_save(parsed)

func save_game(data: Dictionary) -> bool:
	var normalized := _normalize_save(data)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(normalized, "\t"))
	file.close()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _normalize_save(data: Dictionary) -> Dictionary:
	var normalized := create_default_save()
	_copy_legacy_fields(data, normalized)
	_normalize_campaign(data, normalized)
	_normalize_characters(data, normalized)
	_normalize_codex(data, normalized)
	_normalize_resources(data, normalized)
	return normalized

func _copy_legacy_fields(data: Dictionary, normalized: Dictionary) -> void:
	if _is_integer_number(data.get("materials")):
		normalized["materials"] = _normalized_integer(data["materials"], 0)
	if typeof(data.get("equipment_levels")) == TYPE_DICTIONARY:
		normalized["equipment_levels"] = _normalize_equipment_levels(data["equipment_levels"])
	if typeof(data.get("settings")) == TYPE_DICTIONARY:
		var settings: Dictionary = Dictionary(data["settings"]).duplicate(true)
		var default_settings: Dictionary = normalized["settings"]
		for volume_key in ["music_volume", "sfx_volume"]:
			var volume_value = settings.get(volume_key)
			if typeof(volume_value) in [TYPE_INT, TYPE_FLOAT]:
				settings[volume_key] = clampf(float(volume_value), 0.0, 1.0)
			else:
				settings[volume_key] = float(default_settings[volume_key])
		normalized["settings"] = settings

	var unlocked_equipment := _normalize_string_array(data.get("unlocked_equipment", []))
	for equipment_id in DEFAULT_UNLOCKED_EQUIPMENT:
		if not unlocked_equipment.has(equipment_id):
			unlocked_equipment.append(equipment_id)
	normalized["unlocked_equipment"] = unlocked_equipment

func _normalize_campaign(data: Dictionary, normalized: Dictionary) -> void:
	if typeof(data.get("campaign")) != TYPE_DICTIONARY:
		return

	var campaign: Dictionary = data["campaign"]
	var target: Dictionary = normalized["campaign"]
	target["completed_missions"] = _normalize_id_integer_dictionary(campaign.get("completed_missions", {}), known_mission_ids, 0)
	target["unlocked_missions"] = _normalize_known_id_array(campaign.get("unlocked_missions", []), known_mission_ids, DEFAULT_MISSION_ID)
	var chapter_marks := _normalize_id_integer_dictionary(campaign.get("chapter_marks", {}), known_chapter_ids, 0)
	if not chapter_marks.has(DEFAULT_CHAPTER_ID):
		chapter_marks[DEFAULT_CHAPTER_ID] = 0
	target["chapter_marks"] = chapter_marks
	if typeof(campaign.get("selected_mission_id")) == TYPE_STRING and _is_known_id(campaign["selected_mission_id"], known_mission_ids):
		target["selected_mission_id"] = campaign["selected_mission_id"]
	normalized["campaign"] = target

func _normalize_characters(data: Dictionary, normalized: Dictionary) -> void:
	if typeof(data.get("characters")) != TYPE_DICTIONARY:
		return

	var characters: Dictionary = data["characters"]
	var target: Dictionary = normalized["characters"]
	var unlocked_ids := _normalize_known_id_array(characters.get("unlocked_ids", []), known_character_ids, DEFAULT_CHARACTER_ID)
	target["unlocked_ids"] = unlocked_ids

	var source_experience: Dictionary = characters.get("mastery_experience", {}) if typeof(characters.get("mastery_experience")) == TYPE_DICTIONARY else {}
	var source_levels: Dictionary = characters.get("mastery_levels", {}) if typeof(characters.get("mastery_levels")) == TYPE_DICTIONARY else {}
	var experience := _normalize_id_integer_dictionary(source_experience, known_character_ids, 0)
	var levels: Dictionary = {}
	for character_id in unlocked_ids:
		var level_value = source_levels.get(character_id)
		if _is_integer_number(level_value):
			levels[character_id] = clampi(_normalized_integer(level_value, 1), 1, 10)
		else:
			levels[character_id] = _get_level_for_experience(experience.get(character_id, 0))
		if not experience.has(character_id):
			experience[character_id] = 0
	target["mastery_levels"] = levels
	target["mastery_experience"] = experience

	if typeof(characters.get("selected_id")) == TYPE_STRING and unlocked_ids.has(characters["selected_id"]):
		target["selected_id"] = characters["selected_id"]
	target["starting_loadouts"] = _normalize_loadouts(characters.get("starting_loadouts", {}))
	normalized["characters"] = target

func _normalize_codex(data: Dictionary, normalized: Dictionary) -> void:
	if typeof(data.get("codex")) != TYPE_DICTIONARY:
		return
	var codex: Dictionary = data["codex"]
	if typeof(codex.get("unlocked_entries")) == TYPE_ARRAY:
		var target: Dictionary = normalized["codex"]
		target["unlocked_entries"] = _normalize_string_array(codex["unlocked_entries"])
		normalized["codex"] = target

func _normalize_resources(data: Dictionary, normalized: Dictionary) -> void:
	if typeof(data.get("resources")) != TYPE_DICTIONARY:
		return
	var resources: Dictionary = data["resources"]
	if _is_integer_number(resources.get("demon_cores")):
		var target: Dictionary = normalized["resources"]
		target["demon_cores"] = _normalized_integer(resources["demon_cores"], 0)
		normalized["resources"] = target

func _make_id_set(ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for id in ids:
		if not id.is_empty():
			result[id] = true
	return result

func _normalize_known_id_array(value: Variant, known_ids: Dictionary, required_id: String) -> Array:
	var normalized := [required_id]
	if typeof(value) != TYPE_ARRAY:
		return normalized
	for id in value:
		if typeof(id) == TYPE_STRING and _is_known_id(id, known_ids) and not normalized.has(id):
			normalized.append(id)
	return normalized

func _normalize_string_array(value: Variant) -> Array:
	var normalized: Array = []
	if typeof(value) != TYPE_ARRAY:
		return normalized
	for entry in value:
		if typeof(entry) == TYPE_STRING and not normalized.has(entry):
			normalized.append(entry)
	return normalized

func _normalize_id_integer_dictionary(value: Variant, known_ids: Dictionary, minimum: int) -> Dictionary:
	var normalized: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return normalized
	for id in Dictionary(value):
		var amount = Dictionary(value)[id]
		if typeof(id) == TYPE_STRING and _is_known_id(id, known_ids) and _is_integer_number(amount):
			normalized[id] = _normalized_integer(amount, minimum)
	return normalized

func _normalize_equipment_levels(value: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for equipment_id in value:
		var level = value[equipment_id]
		if typeof(equipment_id) == TYPE_STRING and _is_integer_number(level):
			normalized[equipment_id] = _normalized_integer(level, 0)
	return normalized

func _normalize_loadouts(value: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		return normalized
	for character_id in Dictionary(value):
		var loadout = Dictionary(value)[character_id]
		if typeof(character_id) == TYPE_STRING and _is_known_id(character_id, known_character_ids) and typeof(loadout) == TYPE_DICTIONARY:
			normalized[character_id] = Dictionary(loadout).duplicate(true)
	return normalized

func _is_known_id(id: String, known_ids: Dictionary) -> bool:
	return known_ids.has(id)

func _is_integer_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_equal_approx(float(value), round(float(value))))

func _normalized_integer(value: Variant, minimum: int) -> int:
	return maxi(minimum, int(value))

func _get_level_for_experience(experience: int) -> int:
	if CharacterProgression != null:
		return CharacterProgression.new().get_level_for_experience(experience)
	return 1
