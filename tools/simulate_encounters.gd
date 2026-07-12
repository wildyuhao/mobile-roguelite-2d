extends SceneTree

func _initialize() -> void:
	var database = load("res://scripts/data/game_database.gd").new()
	if not database.load_all():
		push_error("Database errors: %s" % str(database.errors))
		quit(1)
		return
	var simulator = load("res://scripts/systems/encounter_simulator.gd").new()
	var report: Dictionary = simulator.simulate(
		database.get_encounters(),
		900.0,
		20260712
	)
	print(JSON.stringify(report))
	var valid := (
		int(report.get("draw_count", 0)) >= 14
		and int(report.get("triple_repeats", 1)) == 0
		and int(report.get("unique_count", 0)) >= 6
		and float(report.get("ranged_share", 1.0)) <= 0.35
	)
	quit(0 if valid else 1)
