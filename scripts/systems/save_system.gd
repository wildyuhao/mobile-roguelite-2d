extends RefCounted
class_name SaveSystem

const DEFAULT_UNLOCKED_EQUIPMENT := ["talisman_robe", "cloudstep_boots", "bronze_gear_core", "jade_compass", "sword_gourd"]

var save_path: String

func _init(new_save_path: String = "user://save.json") -> void:
	save_path = new_save_path

func create_default_save() -> Dictionary:
	return {
		"version": 1,
		"materials": 0,
		"equipment_levels": {},
		"unlocked_equipment": DEFAULT_UNLOCKED_EQUIPMENT.duplicate(),
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 0.8
		}
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
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _normalize_save(data: Dictionary) -> Dictionary:
	var normalized := data.duplicate(true)
	if not normalized.has("unlocked_equipment") or typeof(normalized["unlocked_equipment"]) != TYPE_ARRAY:
		normalized["unlocked_equipment"] = []

	var unlocked: Array = normalized["unlocked_equipment"]
	for equipment_id in DEFAULT_UNLOCKED_EQUIPMENT:
		if not unlocked.has(equipment_id):
			unlocked.append(equipment_id)
	normalized["unlocked_equipment"] = unlocked
	return normalized
