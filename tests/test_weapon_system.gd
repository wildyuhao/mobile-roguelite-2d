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

	system.level_weapon("flying_sword")
	system.level_weapon("flying_sword")
	if system.has_method("get_weapon_pierce"):
		runner.assert_eq(system.get_weapon_pierce("flying_sword"), 1, "flying sword level 4 pierce modifier applies")
	else:
		runner.assert_true(false, "weapon system should expose get_weapon_pierce")

	var fire_system = weapon_system_script.new()
	fire_system.add_weapon(db.get_weapon("talisman_fire"))
	fire_system.level_weapon("talisman_fire")
	fire_system.level_weapon("talisman_fire")
	var talisman_events = fire_system.tick(1.2)
	runner.assert_eq(talisman_events.size(), 1, "talisman fire should fire after cooldown")
	runner.assert_eq(talisman_events[0].get("weapon_type", ""), "projectile", "talisman fire event type")
	runner.assert_eq(talisman_events[0].get("area_size", 0), 96, "talisman fire level 3 area modifier applies")
	fire_system.free()

	var crossbow_system = weapon_system_script.new()
	crossbow_system.add_weapon(db.get_weapon("mechanism_crossbow"))
	var crossbow_events = crossbow_system.tick(0.5)
	runner.assert_eq(crossbow_events.size(), 1, "mechanism crossbow should fire quickly")
	runner.assert_eq(crossbow_events[0].get("pierce", 0), 1, "mechanism crossbow should start with piercing bolts")
	crossbow_system.free()

	var bell_system = weapon_system_script.new()
	bell_system.add_weapon(db.get_weapon("demon_sealing_bell"))
	bell_system.level_weapon("demon_sealing_bell")
	var bell_events = bell_system.tick(2.3)
	runner.assert_eq(bell_events.size(), 1, "demon-sealing bell should emit after cooldown")
	runner.assert_eq(bell_events[0].get("weapon_type", ""), "pulse", "bell should emit a pulse event")
	runner.assert_eq(bell_events[0].get("range", 0), 220, "bell level 2 range modifier applies")
	runner.assert_eq(bell_events[0].get("knockback", 0), 80, "bell event includes knockback")
	bell_system.free()
	system.free()
