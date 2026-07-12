extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/encounter_simulator.gd"):
		runner.assert_true(false, "encounter simulator should exist")
		return
	var database = load("res://scripts/data/game_database.gd").new()
	runner.assert_true(database.load_all(), "simulator database should load")
	var simulator = load("res://scripts/systems/encounter_simulator.gd").new()
	var report: Dictionary = simulator.simulate(
		database.get_encounters(),
		900.0,
		20260712
	)
	runner.assert_true(
		int(report.get("draw_count", 0)) >= 14,
		"fifteen minutes should contain repeated encounter draws"
	)
	runner.assert_true(
		int(report.get("unique_count", 0)) >= 6,
		"simulation should exercise most encounter cards"
	)
	runner.assert_eq(
		report.get("triple_repeats", -1),
		0,
		"simulation should contain no triple repeats"
	)
	runner.assert_true(
		float(report.get("ranged_share", 1.0)) <= 0.35,
		"simulated ranged share should stay capped"
	)
