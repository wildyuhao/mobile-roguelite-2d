extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/data/game_database.gd"):
		runner.assert_true(false, "database script should exist")
		return
	if not ResourceLoader.exists("res://scripts/systems/weapon_system.gd"):
		runner.assert_true(false, "weapon system script should exist")
		return

	var game_database_script = load("res://scripts/data/game_database.gd")
	var weapon_system_script = load("res://scripts/systems/weapon_system.gd")

	var db = game_database_script.new()
	runner.assert_true(db.load_all(), "database should load before weapon tests")

	var system = weapon_system_script.new()
	system.add_weapon(db.get_weapon("flying_sword"))

	runner.assert_eq(system.get_weapon_level("flying_sword"), 1, "new weapon starts at level 1")
	runner.assert_eq(system.tick(0.4).size(), 0, "weapon should not fire before cooldown")

	var fire_events = system.tick(0.6)
	runner.assert_eq(fire_events.size(), 1, "weapon should fire after cooldown")
	runner.assert_eq(fire_events[0]["weapon_id"], "flying_sword", "fire event weapon id")
	runner.assert_eq(fire_events[0]["damage"], 12, "fire event base damage")

	system.level_weapon("flying_sword")
	runner.assert_eq(system.get_weapon_level("flying_sword"), 2, "weapon level increments")
	runner.assert_eq(system.get_weapon_damage("flying_sword"), 16, "level 2 damage modifier applies")
	system.free()
