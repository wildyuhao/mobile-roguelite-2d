extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/formation_planner.gd"):
		runner.assert_true(false, "formation planner should exist")
		return
	var database_script = load("res://scripts/data/game_database.gd")
	var database = database_script.new()
	runner.assert_true(database.load_all(), "formation test database should load")
	var planner = load("res://scripts/systems/formation_planner.gd").new()
	for formation_id in database.get_formations().keys():
		var formation: Dictionary = database.get_formations()[formation_id]
		var first: Array[Vector2] = planner.build_slots(
			formation,
			12,
			360.0,
			0.0
		)
		var second: Array[Vector2] = planner.build_slots(
			formation,
			12,
			360.0,
			0.0
		)
		runner.assert_eq(
			first.size(),
			12,
			"%s should create every requested slot" % formation_id
		)
		runner.assert_eq(
			first,
			second,
			"%s should be deterministic" % formation_id
		)
		for slot in first:
			runner.assert_true(slot.length() > 0.0, "%s slots should be placed away from the player" % formation_id)
	if database.get_formations().has("surround_gap"):
		var slots: Array[Vector2] = planner.build_slots(
			database.get_formations()["surround_gap"],
			18,
			360.0,
			0.0
		)
		for slot in slots:
			runner.assert_true(
				absf(wrapf(slot.angle(), -PI, PI)) >= deg_to_rad(34.0),
				"surround should preserve the escape lane"
			)
