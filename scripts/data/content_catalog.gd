extends RefCounted
class_name ContentCatalog

var chapters: Dictionary = {}
var missions: Dictionary = {}
var characters: Dictionary = {}
var environments: Dictionary = {}
var encounter_decks: Dictionary = {}
var errors: Array[String] = []

func load_all(battle_database: Object) -> bool:
	errors.clear()
	chapters = _array_to_id_map(_load_json_array("res://data/campaign/chapters.json"), "chapter")
	environments = _array_to_id_map(_load_json_array("res://data/campaign/environments.json"), "environment")
	encounter_decks = _array_to_id_map(_load_json_array("res://data/campaign/encounter_decks.json"), "encounter deck")
	missions = _load_directory_arrays_as_id_map("res://data/missions", "mission")
	characters = _load_directory_as_id_map("res://data/characters", "character")
	_validate_catalog(battle_database)
	return errors.is_empty()

func get_chapters() -> Dictionary:
	return chapters

func get_missions() -> Dictionary:
	return missions

func get_mission(id: String) -> Dictionary:
	return missions.get(id, {})

func get_mission_by_chapter_order(chapter_id: String, order: int) -> Dictionary:
	for mission in missions.values():
		if String(mission.get("chapter_id", "")) == chapter_id and int(mission.get("order", 0)) == order:
			return mission
	return {}

func get_characters() -> Dictionary:
	return characters

func get_character(id: String) -> Dictionary:
	return characters.get(id, {})

func get_environments() -> Dictionary:
	return environments

func get_encounter_decks() -> Dictionary:
	return encounter_decks

func _load_directory_as_id_map(path: String, label: String) -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		errors.append("Cannot open data directory: %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_add_to_id_map(result, _load_json_dictionary("%s/%s" % [path, file_name]), label)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _load_directory_arrays_as_id_map(path: String, label: String) -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		errors.append("Cannot open data directory: %s" % path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			for item in _load_json_array("%s/%s" % [path, file_name]):
				_add_to_id_map(result, item, label)
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

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		errors.append("Invalid JSON: %s" % path)
	return parsed

func _array_to_id_map(items: Array[Dictionary], label: String) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		_add_to_id_map(result, item, label)
	return result

func _add_to_id_map(result: Dictionary, item: Dictionary, label: String) -> void:
	var id := String(item.get("id", ""))
	if id == "":
		errors.append("%s definition has no id" % label)
	elif result.has(id):
		errors.append("Duplicate %s id: %s" % [label, id])
	else:
		result[id] = item

func _validate_catalog(battle_database: Object) -> void:
	_validate_chapters()
	_validate_environments()
	_validate_encounter_decks(battle_database)
	_validate_missions(battle_database)
	_validate_characters(battle_database)

func _validate_chapters() -> void:
	for expected_order in range(1, chapters.size() + 1):
		var found := false
		for chapter in chapters.values():
			if int(chapter.get("order", 0)) == expected_order:
				found = true
				break
		if not found:
			errors.append("Chapter order gap at %d" % expected_order)

	for chapter in chapters.values():
		var first_mission_id := String(chapter.get("first_mission_id", ""))
		if bool(chapter.get("implemented", false)) and first_mission_id == "":
			errors.append("Implemented chapter %s has no first mission" % chapter.get("id", ""))
		elif first_mission_id != "" and not missions.has(first_mission_id):
			errors.append("Chapter %s references missing mission %s" % [chapter.get("id", ""), first_mission_id])

func _validate_environments() -> void:
	for environment in environments.values():
		var environment_id := String(environment.get("id", ""))
		var chapter_id := String(environment.get("chapter_id", ""))
		if not chapters.has(chapter_id):
			errors.append("Environment %s references missing chapter %s" % [environment_id, chapter_id])
		_validate_resource(environment_id, "ground texture", String(environment.get("ground_texture_path", "")))

func _validate_encounter_decks(battle_database: Object) -> void:
	var encounter_ids := _get_battle_ids(battle_database, "get_encounters", "encounter")
	for deck in encounter_decks.values():
		var deck_id := String(deck.get("id", ""))
		var chapter_id := String(deck.get("chapter_id", ""))
		if not chapters.has(chapter_id):
			errors.append("Encounter deck %s references missing chapter %s" % [deck_id, chapter_id])
		for encounter_id_value in Array(deck.get("encounter_ids", [])):
			var encounter_id := String(encounter_id_value)
			if not encounter_ids.has(encounter_id):
				errors.append("Encounter deck %s references missing encounter %s" % [deck_id, encounter_id])

func _validate_missions(battle_database: Object) -> void:
	var enemies := _get_battle_ids(battle_database, "get_enemies", "enemy")
	var mission_orders: Dictionary = {}
	for mission in missions.values():
		var mission_id := String(mission.get("id", ""))
		var chapter_id := String(mission.get("chapter_id", ""))
		var mission_order := int(mission.get("order", 0))
		var order_key := "%s:%d" % [chapter_id, mission_order]
		if mission_orders.has(order_key):
			errors.append("Duplicate mission chapter/order pair: %s" % order_key)
		mission_orders[order_key] = true
		if not chapters.has(chapter_id):
			errors.append("Mission %s references missing chapter %s" % [mission_id, chapter_id])
		if not environments.has(String(mission.get("environment_id", ""))):
			errors.append("Mission %s references missing environment %s" % [mission_id, mission.get("environment_id", "")])
		if not encounter_decks.has(String(mission.get("encounter_deck_id", ""))):
			errors.append("Mission %s references missing encounter deck %s" % [mission_id, mission.get("encounter_deck_id", "")])
		for prerequisite_value in Array(mission.get("prerequisites", [])):
			var prerequisite_id := String(prerequisite_value)
			if not missions.has(prerequisite_id):
				errors.append("Mission %s references missing prerequisite %s" % [mission_id, prerequisite_id])
		var boss_id := String(mission.get("boss_id", ""))
		if String(mission.get("type", "")) == "boss" and boss_id == "":
			errors.append("Boss mission %s has no boss" % mission_id)
		elif boss_id != "" and not enemies.has(boss_id):
			errors.append("Mission %s references missing boss %s" % [mission_id, boss_id])
		if int(mission.get("estimated_minutes", 0)) <= 0:
			errors.append("Mission %s has nonpositive estimated minutes" % mission_id)
		var objective: Dictionary = mission.get("objective", {})
		if objective.has("duration") and int(objective.get("duration", 0)) <= 0:
			errors.append("Mission %s has nonpositive duration" % mission_id)
		_validate_rewards(mission_id, mission)
	_validate_first_chapter_missions()

func _validate_rewards(mission_id: String, mission: Dictionary) -> void:
	var first_materials := _validate_reward(mission_id, "first", Dictionary(mission.get("first_reward", {})))
	var repeat_materials := _validate_reward(mission_id, "repeat", Dictionary(mission.get("repeat_reward", {})))
	if first_materials <= 0 or repeat_materials <= 0:
		return
	if repeat_materials >= first_materials:
		errors.append("Mission %s repeat reward must grant fewer materials" % mission_id)
	var first_tokens := Array(Dictionary(mission.get("first_reward", {})).get("unlock_tokens", []))
	if first_tokens.size() != 1 or String(first_tokens[0]) == "":
		errors.append("Mission %s first reward must grant one unlock token" % mission_id)
	if String(mission.get("type", "")) in ["hunt", "boss"]:
		for reward_name in ["first_reward", "repeat_reward"]:
			if int(Dictionary(mission.get(reward_name, {})).get("materials", {}).get("demon_cores", 0)) <= 0:
				errors.append("Mission %s %s must grant demon cores" % [mission_id, reward_name])

func _validate_reward(mission_id: String, reward_type: String, reward: Dictionary) -> int:
	var total := 0
	var materials: Dictionary = reward.get("materials", {})
	if materials.is_empty():
		errors.append("Mission %s %s reward has no materials" % [mission_id, reward_type])
	for material_id in materials.keys():
		var amount := int(materials[material_id])
		if amount <= 0:
			errors.append("Mission %s %s reward has nonpositive %s" % [mission_id, reward_type, material_id])
		total += amount
	return total

func _validate_first_chapter_missions() -> void:
	var first_chapter_id := ""
	for chapter in chapters.values():
		if int(chapter.get("order", 0)) == 1:
			first_chapter_id = String(chapter.get("id", ""))
			break
	var expected_types := ["survival", "seal", "hunt", "mutation", "boss"]
	var first_chapter_mission_count := 0
	for mission in missions.values():
		if String(mission.get("chapter_id", "")) == first_chapter_id:
			first_chapter_mission_count += 1
	if first_chapter_mission_count != expected_types.size():
		errors.append("First chapter must contain exactly five missions")
	for order in range(1, expected_types.size() + 1):
		var mission := get_mission_by_chapter_order(first_chapter_id, order)
		if mission.is_empty() or String(mission.get("type", "")) != expected_types[order - 1]:
			errors.append("First chapter must use required mission type at order %d" % order)
	for mission in missions.values():
		if String(mission.get("chapter_id", "")) == first_chapter_id and int(mission.get("order", 0)) > expected_types.size():
			errors.append("First chapter contains an extra mission")

func _validate_characters(battle_database: Object) -> void:
	var weapons := _get_battle_ids(battle_database, "get_weapons", "weapon")
	for character in characters.values():
		var character_id := String(character.get("id", ""))
		var weapon_id := String(character.get("starting_weapon_id", ""))
		if not weapons.has(weapon_id):
			errors.append("Character %s references missing weapon %s" % [character_id, weapon_id])
		_validate_resource(character_id, "scene", String(character.get("scene_path", "")))
		_validate_resource(character_id, "portrait", String(character.get("portrait_path", "")))
		var mastery_rewards := Array(character.get("mastery_rewards", []))
		if mastery_rewards.size() != 10:
			errors.append("Character %s must define ten mastery rewards" % character_id)
		for index in range(mastery_rewards.size()):
			var reward: Dictionary = mastery_rewards[index]
			if int(reward.get("level", 0)) != index + 1:
				errors.append("Character %s mastery rewards must be sequential" % character_id)
				break

func _get_battle_ids(battle_database: Object, method_name: String, label: String) -> Dictionary:
	var result: Dictionary = {}
	if battle_database == null or not battle_database.has_method(method_name):
		errors.append("Battle database does not expose %s" % method_name)
		return result
	var definitions = battle_database.call(method_name)
	if typeof(definitions) == TYPE_DICTIONARY:
		for id in definitions.keys():
			result[String(id)] = true
	elif typeof(definitions) == TYPE_ARRAY:
		for definition in definitions:
			if typeof(definition) == TYPE_DICTIONARY:
				result[String(definition.get("id", ""))] = true
	else:
		errors.append("Battle database returned invalid %s definitions" % label)
	return result

func _validate_resource(owner_id: String, resource_label: String, path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		errors.append("%s %s resource is missing: %s" % [owner_id, resource_label, path])
