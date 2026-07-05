extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/data/game_database.gd"):
		runner.assert_true(false, "database loader script should exist")
		return

	var game_database_script = load("res://scripts/data/game_database.gd")
	var db = game_database_script.new()
	var result = db.load_all()

	runner.assert_true(result, "database load_all should return true")
	runner.assert_true(db.has_weapon("flying_sword"), "database should include flying_sword")
	runner.assert_eq(db.get_weapon("flying_sword")["display_name"], "Flying Sword", "flying_sword display name")
	runner.assert_true(db.has_enemy("basic_demon"), "database should include basic_demon")
	runner.assert_true(db.get_upgrades().size() >= 6, "database should include at least six upgrades")
	runner.assert_true(db.get_wave_events().size() >= 2, "database should include wave events")
