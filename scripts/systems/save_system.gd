extends RefCounted
class_name SaveSystem

var save_path: String

func _init(new_save_path: String = "user://save.json") -> void:
	save_path = new_save_path

func create_default_save() -> Dictionary:
	return {
		"version": 1,
		"materials": 0,
		"equipment_levels": {},
		"unlocked_equipment": ["talisman_robe", "sword_gourd"],
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
	return parsed

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
