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
	runner.assert_near(system.get_weapon_cooldown("flying_sword"), 0.9, 0.001, "flying sword starts with base cooldown")
	if system.has_method("set_stat_modifiers"):
		system.set_stat_modifiers({ "weapon_cooldown_multiplier": -0.1 })
		runner.assert_near(system.get_weapon_cooldown("flying_sword"), 0.81, 0.001, "equipment cooldown modifier should reduce weapon cooldown")
	else:
		runner.assert_true(false, "weapon system should accept equipment stat modifiers")
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

	var damage_system = weapon_system_script.new()
	damage_system.add_weapon(db.get_weapon("flying_sword"))
	damage_system.set_stat_modifiers({ "weapon_damage_multiplier": 0.25 })
	runner.assert_eq(damage_system.get_weapon_damage("flying_sword"), 15, "stat damage multiplier should increase weapon damage")
	damage_system.free()

	var slot_system = weapon_system_script.new()
	slot_system.max_weapon_slots = 99
	for weapon_id in ["flying_sword", "talisman_fire", "mechanism_crossbow", "demon_sealing_bell"]:
		runner.assert_true(
			slot_system.add_weapon(db.get_weapon(weapon_id)) == true,
			"the first four weapon slots should accept %s" % weapon_id
		)
	runner.assert_true(
		slot_system.add_weapon(db.get_weapon("spirit_needle_array")) != true,
		"the fifth weapon should be rejected"
	)
	runner.assert_eq(slot_system.weapons.size(), 4, "weapon system should enforce four weapon slots even when configured higher")
	runner.assert_true(not slot_system.has_weapon("spirit_needle_array"), "rejected fifth weapon should stay unavailable")
	slot_system.free()

	runner.assert_true(db.has_weapon("spirit_needle_array"), "database should include Spirit Needle Array")
	if db.has_weapon("spirit_needle_array"):
		var needle_system = weapon_system_script.new()
		needle_system.add_weapon(db.get_weapon("spirit_needle_array"))
		var needle_events = needle_system.tick(1.3)
		runner.assert_eq(needle_events.size(), 1, "Spirit Needle Array should fire after its base cooldown")
		if not needle_events.is_empty():
			runner.assert_eq(needle_events[0].get("aim_mode", ""), "radial", "Spirit Needle Array should use radial aiming")
			runner.assert_eq(needle_events[0].get("projectile_count", 0), 6, "Spirit Needle Array should start with six needles")
			runner.assert_eq(needle_events[0].get("projectile_texture_path", ""), "res://art/weapons/spirit_needle_array/spirit_needle_projectile.png", "Spirit Needle Array should identify its production projectile")
		needle_system.level_weapon("spirit_needle_array")
		needle_system.level_weapon("spirit_needle_array")
		var level_three_events = needle_system.tick(1.3)
		if not level_three_events.is_empty():
			runner.assert_eq(level_three_events[0].get("projectile_count", 0), 8, "Spirit Needle Array level three should fire eight needles")
		needle_system.free()
	system.free()
