extends RefCounted

const RunContextBuilderScript = preload("res://scripts/core/run_context_builder.gd")
const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const ContentCatalogScript = preload("res://scripts/data/content_catalog.gd")

func run(runner) -> void:
	var battle_db = GameDatabaseScript.new()
	runner.assert_true(battle_db.load_all(), "battle catalog should load before building a run context")
	var catalog = ContentCatalogScript.new()
	runner.assert_true(catalog.load_all(battle_db), "campaign catalog should load before building a run context")
	var builder = RunContextBuilderScript.new()
	var mission: Dictionary = catalog.get_mission("red_wastes_survival")
	var character: Dictionary = catalog.get_character("mechanism_walker")

	var result: Dictionary = builder.build(mission, character, 0, 24680, battle_db, catalog)
	runner.assert_true(result["ok"], "valid campaign selections should build a run context")
	runner.assert_eq(result["context"]["starting_weapon_id"], "mechanism_crossbow", "run context should use the selected character weapon")
	runner.assert_eq(result["context"]["mission_rules"]["kind"], "survive", "run context should copy mission rules")
	runner.assert_eq(result["context"]["mission_seed"], 24680, "explicit mission seed should remain deterministic")

	var deep_copy_mission: Dictionary = mission.duplicate(true)
	deep_copy_mission["objective"] = {"kind": "survive", "nested": {"value": "source"}}
	var deep_copy_result: Dictionary = builder.build(deep_copy_mission, character, 0, 24680, battle_db, catalog)
	deep_copy_result["context"]["mission_rules"]["nested"]["value"] = "changed"
	runner.assert_eq(deep_copy_mission["objective"]["nested"]["value"], "source", "run context mission rules should be a deep copy")

	var generated_seed_result: Dictionary = builder.build(mission, character, 0, 0, battle_db, catalog)
	runner.assert_true(generated_seed_result["context"]["mission_seed"] != 0, "zero seed should generate a mission seed")

	_assert_invalid_result(
		runner,
		builder.build({}, character, 0, 24680, battle_db, catalog),
		["missing_mission", "missing_encounter_deck", "missing_environment"],
		"empty mission should report every missing mission reference"
	)

	var unknown_weapon_character: Dictionary = character.duplicate(true)
	unknown_weapon_character["starting_weapon_id"] = "unknown_weapon"
	_assert_invalid_result(
		runner,
		builder.build(mission, unknown_weapon_character, 0, 24680, battle_db, catalog),
		["missing_starting_weapon"],
		"unknown starting weapon should be rejected"
	)

	var unknown_deck_mission: Dictionary = mission.duplicate(true)
	unknown_deck_mission["encounter_deck_id"] = "unknown_deck"
	_assert_invalid_result(
		runner,
		builder.build(unknown_deck_mission, character, 0, 24680, battle_db, catalog),
		["missing_encounter_deck"],
		"unknown encounter deck should be rejected"
	)

	_assert_invalid_result(
		runner,
		builder.build(mission, character, -1, 24680, battle_db, catalog),
		["invalid_difficulty_mark"],
		"negative difficulty mark should be rejected"
	)

func _assert_invalid_result(runner, result: Dictionary, expected_errors: Array[String], message: String) -> void:
	runner.assert_true(not result["ok"], message)
	runner.assert_eq(result["context"], {}, "%s should return an empty context" % message)
	runner.assert_eq(result["errors"], expected_errors, "%s should return exact errors" % message)
