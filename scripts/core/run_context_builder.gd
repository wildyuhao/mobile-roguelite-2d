extends RefCounted
class_name RunContextBuilder

func build(
	mission: Dictionary,
	character: Dictionary,
	difficulty_mark: int,
	seed_value: int,
	battle_database: Object,
	content_catalog: Object,
) -> Dictionary:
	var errors: Array[String] = []
	var mission_id := String(mission.get("id", ""))
	var character_id := String(character.get("id", ""))
	var weapon_id := String(character.get("starting_weapon_id", ""))
	var deck_id := String(mission.get("encounter_deck_id", ""))
	var environment_id := String(mission.get("environment_id", ""))
	if mission_id == "":
		errors.append("missing_mission")
	if character_id == "":
		errors.append("missing_character")
	if difficulty_mark < 0:
		errors.append("invalid_difficulty_mark")
	if battle_database == null or not battle_database.has_weapon(weapon_id):
		errors.append("missing_starting_weapon")
	if content_catalog == null or not content_catalog.get_encounter_decks().has(deck_id):
		errors.append("missing_encounter_deck")
	if content_catalog == null or not content_catalog.get_environments().has(environment_id):
		errors.append("missing_environment")
	if not errors.is_empty():
		return {"ok": false, "context": {}, "errors": errors}
	return {
		"ok": true,
		"context": {
			"mission_id": mission_id,
			"chapter_id": String(mission.get("chapter_id", "")),
			"character_id": character_id,
			"starting_weapon_id": weapon_id,
			"mission_seed": seed_value if seed_value != 0 else Time.get_ticks_usec(),
			"difficulty_mark": difficulty_mark,
			"mission_rules": Dictionary(mission.get("objective", {})).duplicate(true),
			"encounter_deck_id": deck_id,
			"environment_id": environment_id,
			"boss_id": String(mission.get("boss_id", "")),
		},
		"errors": [],
	}
