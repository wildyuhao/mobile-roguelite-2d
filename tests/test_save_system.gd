extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/save_system.gd"):
		runner.assert_true(false, "save system script should exist")
		return

	var save_system_script = load("res://scripts/systems/save_system.gd")
	var save_system = save_system_script.new("user://test_fuji_save.json")
	var data = save_system.create_default_save()
	data["materials"] = 17
	data["equipment_levels"]["talisman_robe"] = 2

	runner.assert_true(save_system.save_game(data), "save_game should return true")
	var loaded = save_system.load_game()
	runner.assert_eq(loaded["materials"], 17, "loaded materials should match saved data")
	runner.assert_eq(loaded["equipment_levels"]["talisman_robe"], 2, "loaded equipment level should match saved data")
	save_system.delete_save()
