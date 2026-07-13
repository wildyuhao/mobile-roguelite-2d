extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/data/content_catalog.gd"):
		runner.assert_true(false, "campaign catalog loader script should exist")
		return

	var battle_db = load("res://scripts/data/game_database.gd").new()
	runner.assert_true(battle_db.load_all(), "battle catalog should load first")
	var catalog = load("res://scripts/data/content_catalog.gd").new()
	runner.assert_true(catalog.load_all(battle_db), "campaign catalog should validate")
	runner.assert_eq(catalog.get_chapters().size(), 6, "campaign should expose six ordered chapters")
	runner.assert_eq(catalog.get_missions().size(), 5, "first campaign slice should expose five missions")
	runner.assert_eq(catalog.get_characters().size(), 1, "first campaign slice should expose the default character")

	var expected_types := ["survival", "seal", "hunt", "mutation", "boss"]
	for order in range(1, 6):
		var mission: Dictionary = catalog.get_mission_by_chapter_order("red_wastes", order)
		runner.assert_eq(mission.get("type", ""), expected_types[order - 1], "mission order should match the chapter contract")
		var first_reward: Dictionary = mission.get("first_reward", {})
		var repeat_reward: Dictionary = mission.get("repeat_reward", {})
		runner.assert_eq(typeof(first_reward.get("materials")), TYPE_INT, "first mission materials should use the save v2 scalar shape")
		runner.assert_eq(typeof(repeat_reward.get("materials")), TYPE_INT, "repeat mission materials should use the save v2 scalar shape")
		runner.assert_eq(typeof(first_reward.get("demon_cores")), TYPE_INT, "first mission demon cores should use a scalar integer")
		runner.assert_eq(typeof(repeat_reward.get("demon_cores")), TYPE_INT, "repeat mission demon cores should use a scalar integer")
		if typeof(first_reward.get("materials")) == TYPE_INT and typeof(repeat_reward.get("materials")) == TYPE_INT:
			runner.assert_true(int(first_reward["materials"]) > 0, "first mission materials should be positive")
			runner.assert_true(int(repeat_reward["materials"]) > 0, "repeat mission materials should be positive")
			runner.assert_true(int(repeat_reward["materials"]) < int(first_reward["materials"]), "repeat mission materials should be below first materials")
		var unlock_tokens := Array(first_reward.get("unlock_tokens", []))
		runner.assert_eq(unlock_tokens.size(), 1, "each first reward should contain exactly one unlock token")
		if unlock_tokens.size() == 1:
			runner.assert_true(typeof(unlock_tokens[0]) == TYPE_STRING and not String(unlock_tokens[0]).is_empty(), "first reward unlock token should be a nonempty string")
		if mission.get("type", "") in ["hunt", "boss"]:
			runner.assert_true(int(first_reward.get("demon_cores", 0)) > 0, "hunt and boss first rewards should grant demon cores")
			runner.assert_true(int(repeat_reward.get("demon_cores", 0)) > 0, "hunt and boss repeat rewards should grant demon cores")

	var character: Dictionary = catalog.get_character("mechanism_walker")
	runner.assert_eq(character.get("starting_weapon_id", ""), "mechanism_crossbow", "default character should start with the crossbow")
	runner.assert_eq(Array(character.get("mastery_rewards", [])).size(), 10, "character should define ten mastery rewards")
	runner.assert_true(catalog.errors.is_empty(), "valid campaign content should produce no errors")

	var invalid_catalog = load("res://scripts/data/content_catalog.gd").new()
	invalid_catalog.chapters = {"red_wastes": {"id": "red_wastes", "order": 1}}
	for order in range(1, 6):
		invalid_catalog.missions["required_%d" % order] = {
			"chapter_id": "red_wastes",
			"order": order,
			"type": expected_types[order - 1],
		}
	invalid_catalog.missions["extra"] = {
		"chapter_id": "red_wastes",
		"order": 0,
		"type": "survival",
	}
	invalid_catalog._validate_first_chapter_missions()
	runner.assert_true(
		not invalid_catalog.errors.is_empty(),
		"first chapter should reject missions beyond the required five"
	)

	var missing_reference_catalog = _clone_catalog(load("res://scripts/data/content_catalog.gd"), catalog)
	missing_reference_catalog.missions["red_wastes_survival"]["environment_id"] = "missing_environment"
	missing_reference_catalog.missions["red_wastes_seal"]["encounter_deck_id"] = "missing_deck"
	missing_reference_catalog.missions["red_wastes_boss"]["boss_id"] = "missing_boss"
	missing_reference_catalog.characters["mechanism_walker"]["starting_weapon_id"] = "missing_weapon"
	missing_reference_catalog._validate_missions(battle_db)
	missing_reference_catalog._validate_characters(battle_db)
	runner.assert_true(_has_error_containing(missing_reference_catalog.errors, "missing environment missing_environment"), "catalog should reject missing environment references")
	runner.assert_true(_has_error_containing(missing_reference_catalog.errors, "missing encounter deck missing_deck"), "catalog should reject missing encounter deck references")
	runner.assert_true(_has_error_containing(missing_reference_catalog.errors, "missing boss missing_boss"), "catalog should reject missing boss references")
	runner.assert_true(_has_error_containing(missing_reference_catalog.errors, "missing weapon missing_weapon"), "catalog should reject missing weapon references")

	var invalid_container_catalog = _clone_catalog(load("res://scripts/data/content_catalog.gd"), catalog)
	invalid_container_catalog.encounter_decks["red_wastes_deck"]["encounter_ids"] = "four_side_surround"
	invalid_container_catalog.missions["red_wastes_survival"]["prerequisites"] = "none"
	invalid_container_catalog.missions["red_wastes_seal"]["objective"] = "seal_points"
	invalid_container_catalog.characters["mechanism_walker"]["mastery_rewards"] = "ten"
	invalid_container_catalog._validate_encounter_decks(battle_db)
	invalid_container_catalog._validate_missions(battle_db)
	invalid_container_catalog._validate_characters(battle_db)
	runner.assert_true(_has_error_containing(invalid_container_catalog.errors, "encounter_ids must be an array"), "catalog should reject a non-array encounter list without a script error")
	runner.assert_true(_has_error_containing(invalid_container_catalog.errors, "prerequisites must be an array"), "catalog should reject non-array prerequisites without a script error")
	runner.assert_true(_has_error_containing(invalid_container_catalog.errors, "objective must be a dictionary"), "catalog should reject a non-dictionary objective without a script error")
	runner.assert_true(_has_error_containing(invalid_container_catalog.errors, "mastery_rewards must be an array"), "catalog should reject non-array mastery rewards without a script error")

	var invalid_mastery_entry_catalog = _clone_catalog(load("res://scripts/data/content_catalog.gd"), catalog)
	invalid_mastery_entry_catalog.characters["mechanism_walker"]["mastery_rewards"][0] = "base_kit"
	invalid_mastery_entry_catalog._validate_characters(battle_db)
	runner.assert_true(_has_error_containing(invalid_mastery_entry_catalog.errors, "mastery reward 1 must be a dictionary"), "catalog should reject malformed mastery reward entries")

	var invalid_token_catalog = _clone_catalog(load("res://scripts/data/content_catalog.gd"), catalog)
	invalid_token_catalog.missions["red_wastes_survival"]["first_reward"]["unlock_tokens"] = ["missing_unlock"]
	invalid_token_catalog._validate_rewards("red_wastes_survival", invalid_token_catalog.missions["red_wastes_survival"])
	runner.assert_true(_has_error_containing(invalid_token_catalog.errors, "unknown unlock token missing_unlock"), "catalog should reject unknown mission unlock tokens")

	var chapter_gap_catalog = _clone_catalog(load("res://scripts/data/content_catalog.gd"), catalog)
	chapter_gap_catalog.chapters["bamboo_ruins"]["order"] = 3
	chapter_gap_catalog._validate_chapters()
	runner.assert_true(_has_error_containing(chapter_gap_catalog.errors, "Chapter order gap at 2"), "catalog should reject chapter order gaps")

	var production_first_reward: Dictionary = catalog.get_mission("red_wastes_survival").get("first_reward", {})
	if typeof(production_first_reward.get("materials")) == TYPE_INT:
		var invalid_reward_catalog = load("res://scripts/data/content_catalog.gd").new()
		invalid_reward_catalog._validate_rewards("invalid_reward", {
			"type": "survival",
			"first_reward": {"materials": 0, "demon_cores": 0, "unlock_tokens": ["next"]},
			"repeat_reward": {"materials": -1, "demon_cores": 0},
		})
		runner.assert_true(_has_error_containing(invalid_reward_catalog.errors, "first reward has nonpositive materials"), "catalog should reject nonpositive first materials")
		runner.assert_true(_has_error_containing(invalid_reward_catalog.errors, "repeat reward has nonpositive materials"), "catalog should reject nonpositive repeat materials")
	else:
		runner.assert_true(false, "nonpositive scalar reward validation requires the save v2 reward shape")

func _clone_catalog(catalog_script, source):
	var clone = catalog_script.new()
	clone.chapters = source.get_chapters().duplicate(true)
	clone.missions = source.get_missions().duplicate(true)
	clone.characters = source.get_characters().duplicate(true)
	clone.environments = source.get_environments().duplicate(true)
	clone.encounter_decks = source.get_encounter_decks().duplicate(true)
	return clone

func _has_error_containing(errors: Array[String], fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false
