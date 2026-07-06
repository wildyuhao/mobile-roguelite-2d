extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/save_system.gd"):
		runner.assert_true(false, "save system script should exist")
		return

	var save_system_script = load("res://scripts/systems/save_system.gd")
	var save_system = save_system_script.new("user://test_fuji_save.json")
	var data = save_system.create_default_save()
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
		"equipment_levels": {},
		"unlocked_equipment": ["talisman_robe", "sword_gourd"],
		"settings": {},
	}), "legacy save should be writable")
	var migrated = save_system.load_game()
	runner.assert_eq(migrated["materials"], 9, "migrated save should preserve materials")
	runner.assert_true(migrated["unlocked_equipment"].has("cloudstep_boots"), "legacy save should gain boot upgrade access")
	runner.assert_true(migrated["unlocked_equipment"].has("bronze_gear_core"), "legacy save should gain gear core upgrade access")
	runner.assert_true(migrated["unlocked_equipment"].has("jade_compass"), "legacy save should gain compass upgrade access")
	save_system.delete_save()
