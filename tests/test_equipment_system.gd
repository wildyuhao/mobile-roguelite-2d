extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/equipment_system.gd"):
		runner.assert_true(false, "equipment system script should exist")
		return

	var equipment_system_script = load("res://scripts/systems/equipment_system.gd")
	var system = equipment_system_script.new()
	system.configure([
		{ "id": "robe", "stat_modifiers": { "max_health": 10 } },
		{ "id": "boots", "stat_modifiers": { "move_speed": 18 } },
		{ "id": "core", "stat_modifiers": { "weapon_cooldown_multiplier": -0.05 } }
	])
	if system.has_method("set_equipment_levels"):
		system.set_equipment_levels({
			"robe": 3,
			"core": 2,
		})
	else:
		runner.assert_true(false, "equipment system should accept saved equipment levels")
	system.equip(["robe", "boots", "core"])

	var modifiers = system.get_total_modifiers()
	runner.assert_eq(modifiers["max_health"], 30, "equipment level should scale max health")
	runner.assert_eq(modifiers["move_speed"], 18, "equipment should add move speed")
	runner.assert_eq(modifiers["weapon_cooldown_multiplier"], -0.1, "equipment level should scale cooldown modifier")
