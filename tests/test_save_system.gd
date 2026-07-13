extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/save_system.gd"):
		runner.assert_true(false, "save system script should exist")
		return

	var save_system_script = load("res://scripts/systems/save_system.gd")
	var save_system = save_system_script.new("user://test_fuji_save.json")
	var mission_ids: Array[String] = [
		"red_wastes_survival",
		"red_wastes_seal",
		"red_wastes_hunt",
		"red_wastes_mutation",
		"red_wastes_boss",
	]
	var character_ids: Array[String] = ["mechanism_walker"]
	var chapter_ids: Array[String] = ["red_wastes"]
	save_system.configure_content_ids(mission_ids, character_ids, chapter_ids)
	var data = save_system.create_default_save()
	runner.assert_eq(data["version"], 2, "default save should use campaign save version two")
	runner.assert_eq(data["campaign"], {
		"completed_missions": {},
		"unlocked_missions": ["red_wastes_survival"],
		"chapter_marks": {"red_wastes": 0},
		"selected_mission_id": "red_wastes_survival",
	}, "default save should initialize the Red Wastes campaign")
	runner.assert_eq(data["characters"], {
		"unlocked_ids": ["mechanism_walker"],
		"mastery_levels": {"mechanism_walker": 1},
		"mastery_experience": {"mechanism_walker": 0},
		"selected_id": "mechanism_walker",
		"starting_loadouts": {},
	}, "default save should initialize the default character")
	runner.assert_eq(data["codex"], {"unlocked_entries": []}, "default save should initialize the codex")
	runner.assert_eq(data["resources"], {"demon_cores": 0}, "default save should initialize campaign resources")
	runner.assert_true(data["unlocked_equipment"].has("talisman_robe"), "default save should unlock robe upgrades")
	runner.assert_true(data["unlocked_equipment"].has("cloudstep_boots"), "default save should unlock boot upgrades")
	runner.assert_true(data["unlocked_equipment"].has("bronze_gear_core"), "default save should unlock gear core upgrades")
	runner.assert_true(data["unlocked_equipment"].has("jade_compass"), "default save should unlock compass upgrades")
	runner.assert_true(data["unlocked_equipment"].has("sword_gourd"), "default save should preserve starting weapon equipment")
	data["materials"] = 17
	data["equipment_levels"]["talisman_robe"] = 2

	runner.assert_true(save_system.save_game(data), "save_game should return true")
	var loaded = save_system.load_game()
	runner.assert_eq(loaded["materials"], 17, "loaded materials should match saved data")
	runner.assert_eq(loaded["equipment_levels"]["talisman_robe"], 2, "loaded equipment level should match saved data")

	runner.assert_true(save_system.save_game({
		"version": 1,
		"materials": 9,
		"equipment_levels": {"talisman_robe": 3},
		"unlocked_equipment": ["talisman_robe", "sword_gourd"],
		"settings": {"music_volume": 0.35, "sfx_volume": 0.65},
	}), "legacy save should be writable")
	var migrated = save_system.load_game()
	runner.assert_eq(migrated["version"], 2, "legacy saves should migrate to version two")
	runner.assert_eq(migrated["materials"], 9, "migrated save should preserve materials")
	runner.assert_eq(migrated["equipment_levels"], {"talisman_robe": 3}, "migrated save should preserve equipment levels")
	runner.assert_eq(migrated["settings"], {"music_volume": 0.35, "sfx_volume": 0.65}, "migrated save should preserve settings")
	runner.assert_true(migrated["unlocked_equipment"].has("cloudstep_boots"), "legacy save should gain boot upgrade access")
	runner.assert_true(migrated["unlocked_equipment"].has("bronze_gear_core"), "legacy save should gain gear core upgrade access")
	runner.assert_true(migrated["unlocked_equipment"].has("jade_compass"), "legacy save should gain compass upgrade access")
	runner.assert_eq(migrated["campaign"]["selected_mission_id"], "red_wastes_survival", "legacy saves should gain a default selected mission")
	runner.assert_eq(migrated["characters"]["selected_id"], "mechanism_walker", "legacy saves should gain a default selected character")

	runner.assert_true(save_system.save_game({
		"version": 2,
		"materials": -12,
		"campaign": {
			"completed_missions": {"red_wastes_survival": 2, "missing_mission": 4, "red_wastes_hunt": "bad"},
			"unlocked_missions": ["missing_mission", "red_wastes_hunt", 42, "red_wastes_hunt"],
			"chapter_marks": {"red_wastes": 2, "missing_chapter": 5, "red_wastes_bad": "bad"},
			"selected_mission_id": "missing_mission",
		},
		"characters": {
			"unlocked_ids": ["missing_character", "mechanism_walker", 42],
			"mastery_levels": {"mechanism_walker": -4, "missing_character": 7},
			"mastery_experience": {"mechanism_walker": -50, "missing_character": 240},
			"selected_id": "missing_character",
			"starting_loadouts": {"mechanism_walker": {"weapon": "crossbow"}, "missing_character": {"weapon": "none"}},
		},
		"resources": {"demon_cores": -8, "spirit_ore": "bad"},
	}), "malformed v2 save should be writable")
	var normalized = save_system.load_game()
	runner.assert_eq(normalized["materials"], 0, "materials should remain nonnegative")
	runner.assert_eq(normalized["resources"], {"demon_cores": 0}, "resources should remain nonnegative integers")
	runner.assert_eq(normalized["campaign"]["selected_mission_id"], "red_wastes_survival", "unknown selected missions should fall back to the default")
	runner.assert_eq(normalized["campaign"]["completed_missions"], {"red_wastes_survival": 2}, "unknown and malformed mission completion entries should be removed")
	runner.assert_eq(normalized["campaign"]["unlocked_missions"], ["red_wastes_survival", "red_wastes_hunt"], "mission unlocks should be filtered and deduplicated")
	runner.assert_eq(normalized["campaign"]["chapter_marks"], {"red_wastes": 2}, "chapter marks should be filtered and normalized")
	runner.assert_eq(normalized["characters"]["selected_id"], "mechanism_walker", "unknown selected characters should fall back to the default")
	runner.assert_eq(normalized["characters"]["unlocked_ids"], ["mechanism_walker"], "character unlocks should be filtered and deduplicated")
	runner.assert_eq(normalized["characters"]["mastery_levels"], {"mechanism_walker": 1}, "mastery levels should normalize to valid integers")
	runner.assert_eq(normalized["characters"]["mastery_experience"], {"mechanism_walker": 0}, "mastery experience should normalize to valid integers")
	runner.assert_eq(normalized["characters"]["starting_loadouts"], {"mechanism_walker": {"weapon": "crossbow"}}, "unknown character loadouts should be removed")
	save_system.delete_save()

	var unconfigured_path := "user://test_fuji_unconfigured_save.json"
	var unconfigured_save_system = save_system_script.new(unconfigured_path)
	runner.assert_true(unconfigured_save_system.save_game({
		"version": 1,
		"materials": 23,
		"equipment_levels": {"talisman_robe": 4},
		"unlocked_equipment": ["talisman_robe"],
		"settings": {"music_volume": 0.25, "sfx_volume": 0.75},
	}), "unconfigured legacy save should be writable")
	var written = JSON.parse_string(FileAccess.get_file_as_string(unconfigured_path))
	runner.assert_eq(written["version"], 2, "save_game should write version two saves")
	runner.assert_true(written.has("campaign"), "save_game should write campaign state")
	runner.assert_true(written.has("characters"), "save_game should write character state")
	runner.assert_true(written.has("codex"), "save_game should write codex state")
	runner.assert_true(written.has("resources"), "save_game should write resources state")
	runner.assert_eq(written["materials"], 23, "save_game should preserve legacy materials")
	runner.assert_eq(written["equipment_levels"]["talisman_robe"], 4, "save_game should preserve legacy equipment levels")
	runner.assert_eq(written["settings"], {"music_volume": 0.25, "sfx_volume": 0.75}, "save_game should preserve legacy settings")

	runner.assert_true(unconfigured_save_system.save_game({
		"version": 2,
		"campaign": {
			"completed_missions": {"red_wastes_survival": 1, "unknown_mission": 2},
			"unlocked_missions": ["red_wastes_survival", "unknown_mission"],
			"chapter_marks": {"red_wastes": 1, "unknown_chapter": 2},
			"selected_mission_id": "unknown_mission",
		},
		"characters": {
			"unlocked_ids": ["mechanism_walker", "unknown_character"],
			"mastery_levels": {"mechanism_walker": 2, "unknown_character": 3},
			"mastery_experience": {"mechanism_walker": 100, "unknown_character": 240},
			"selected_id": "unknown_character",
		},
	}), "unconfigured malformed v2 save should be writable")
	var unconfigured_normalized = unconfigured_save_system.load_game()
	runner.assert_eq(unconfigured_normalized["campaign"]["completed_missions"], {"red_wastes_survival": 1}, "unconfigured saves should filter unknown missions")
	runner.assert_eq(unconfigured_normalized["campaign"]["unlocked_missions"], ["red_wastes_survival"], "unconfigured saves should filter unknown mission unlocks")
	runner.assert_eq(unconfigured_normalized["campaign"]["chapter_marks"], {"red_wastes": 1}, "unconfigured saves should filter unknown chapters")
	runner.assert_eq(unconfigured_normalized["campaign"]["selected_mission_id"], "red_wastes_survival", "unconfigured saves should fall back from unknown missions")
	runner.assert_eq(unconfigured_normalized["characters"]["unlocked_ids"], ["mechanism_walker"], "unconfigured saves should filter unknown characters")
	runner.assert_eq(unconfigured_normalized["characters"]["mastery_experience"], {"mechanism_walker": 100}, "unconfigured saves should filter unknown character progression")
	runner.assert_eq(unconfigured_normalized["characters"]["selected_id"], "mechanism_walker", "unconfigured saves should fall back from unknown characters")

	var partial_config_path := "user://test_fuji_partial_config_save.json"
	var partial_config_save_system = save_system_script.new(partial_config_path)
	var partial_mission_ids: Array[String] = ["red_wastes_hunt"]
	var partial_character_ids: Array[String] = []
	var partial_chapter_ids: Array[String] = []
	partial_config_save_system.configure_content_ids(partial_mission_ids, partial_character_ids, partial_chapter_ids)
	runner.assert_true(partial_config_save_system.save_game({
		"version": 2,
		"campaign": {
			"completed_missions": {"red_wastes_survival": 1, "red_wastes_hunt": 2},
			"chapter_marks": {"red_wastes": 1},
		},
		"characters": {
			"unlocked_ids": ["mechanism_walker"],
			"mastery_experience": {"mechanism_walker": 100},
		},
	}), "partial configured save should be writable")
	var partial_config_normalized = partial_config_save_system.load_game()
	runner.assert_eq(partial_config_normalized["campaign"]["completed_missions"], {"red_wastes_survival": 1, "red_wastes_hunt": 2}, "configured content IDs should retain the default mission")
	runner.assert_eq(partial_config_normalized["campaign"]["chapter_marks"], {"red_wastes": 1}, "configured content IDs should retain the default chapter")
	runner.assert_eq(partial_config_normalized["characters"]["mastery_experience"], {"mechanism_walker": 100}, "configured content IDs should retain the default character")
	unconfigured_save_system.delete_save()
	partial_config_save_system.delete_save()
