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

	if system.has_method("upgrade_equipment_in_save"):
		var save_data := {
			"materials": 50,
			"equipment_levels": {
				"robe": 2,
			},
			"unlocked_equipment": ["robe", "boots"],
		}
		var result: Dictionary = system.upgrade_equipment_in_save("robe", save_data)
		runner.assert_true(result["success"], "upgrade should succeed with enough materials")
		runner.assert_eq(result["cost"], 20, "upgrade cost should scale from current level")
		runner.assert_eq(save_data["materials"], 30, "successful upgrade should spend materials")
		runner.assert_eq(save_data["equipment_levels"]["robe"], 3, "successful upgrade should increase equipment level")

		var before_unknown = save_data.duplicate(true)
		var insufficient: Dictionary = system.upgrade_equipment_in_save("robe", {
			"materials": 5,
			"equipment_levels": { "robe": 3 },
			"unlocked_equipment": ["robe"],
		})
		runner.assert_true(not insufficient["success"], "upgrade should fail without enough materials")
		runner.assert_eq(insufficient["reason"], "insufficient_materials", "failure reason should explain missing materials")

		var locked_save := {
			"materials": 100,
			"equipment_levels": {},
			"unlocked_equipment": ["boots"],
		}
		var locked: Dictionary = system.upgrade_equipment_in_save("robe", locked_save)
		runner.assert_true(not locked["success"], "locked equipment should not upgrade")
		runner.assert_eq(locked_save.get("materials", 0), 100, "locked upgrade should not spend materials")

		var unknown: Dictionary = system.upgrade_equipment_in_save("missing", save_data)
		runner.assert_true(not unknown["success"], "unknown equipment should not upgrade")
		runner.assert_eq(save_data, before_unknown, "failed unknown upgrade should not mutate save data")
	else:
		runner.assert_true(false, "equipment system should support spending materials to upgrade equipment")
