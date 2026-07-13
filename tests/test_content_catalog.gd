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
