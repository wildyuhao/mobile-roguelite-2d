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
	_assert_early_wave_pressure(runner, db.get_wave_events())
	runner.assert_true(db.has_method("get_weapons"), "database should expose all weapons")
	runner.assert_true(db.has_method("get_enemies"), "database should expose all enemies")
	runner.assert_true(db.get_weapons().size() >= 4, "vertical slice should include at least four weapons")
	runner.assert_true(db.get_enemies().size() >= 5, "vertical slice should include four enemies and one boss")
	runner.assert_true(db.get_equipment().size() >= 6, "vertical slice should include six equipment items")

func _assert_early_wave_pressure(runner, wave_events: Array[Dictionary]) -> void:
	var first_minute_times: Array[float] = []
	for event in wave_events:
		var event_time := float(event.get("time", 9999.0))
		if event_time <= 60.0:
			first_minute_times.append(event_time)
	first_minute_times.sort()

	runner.assert_true(first_minute_times.size() >= 6, "first minute should include enough enemy waves to keep combat active")
	if first_minute_times.size() < 2:
		return
	for index in range(1, first_minute_times.size()):
		var gap := first_minute_times[index] - first_minute_times[index - 1]
		runner.assert_true(gap <= 12.0, "first-minute enemy wave gap should not exceed 12 seconds")
