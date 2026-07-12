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
	runner.assert_true(db.get_upgrades().size() >= 18, "combat density foundation should include at least eighteen upgrades before the fifth weapon")
	runner.assert_true(db.get_wave_events().size() >= 2, "database should include wave events")
	_assert_early_wave_pressure(runner, db.get_wave_events())
	_assert_three_minute_wave_density(runner, db.get_wave_events())
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

func _assert_three_minute_wave_density(runner, wave_events: Array[Dictionary]) -> void:
	var event_times: Array[float] = []
	var enemy_ids: Dictionary = {}
	var total_spawn_count := 0
	for event in wave_events:
		var event_time := float(event.get("time", 9999.0))
		if event_time > 180.0:
			continue
		event_times.append(event_time)
		enemy_ids[String(event.get("enemy_id", ""))] = true
		total_spawn_count += int(event.get("spawn_count", 0))
	event_times.sort()

	runner.assert_true(event_times.size() >= 17, "first three minutes should include at least seventeen wave events")
	runner.assert_true(total_spawn_count >= 145, "first three minutes should request at least 145 enemies")
	runner.assert_true(enemy_ids.has("basic_demon"), "first three minutes should include basic demons")
	runner.assert_true(enemy_ids.has("charging_demon"), "first three minutes should include charging demons")
	runner.assert_true(enemy_ids.has("ranged_demon"), "first three minutes should include ranged demons")
	runner.assert_true(enemy_ids.has("elite_guardian"), "first three minutes should introduce an elite")
	for index in range(1, event_times.size()):
		var gap := event_times[index] - event_times[index - 1]
		runner.assert_true(gap <= 12.0, "three-minute wave gap should not exceed 12 seconds")
