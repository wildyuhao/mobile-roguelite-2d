extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/settlement_system.gd"):
		runner.assert_true(false, "settlement system script should exist")
		return

	var settlement_system_script = load("res://scripts/systems/settlement_system.gd")
	var settlement = settlement_system_script.new()
	var result = settlement.calculate_rewards({
		"defeated_enemies": 12,
		"boss_defeated": true,
		"base_materials": 9
	})

	runner.assert_eq(result["materials"], 39, "settlement should include enemy and boss rewards")
	runner.assert_eq(result["boss_defeated"], true, "settlement should preserve boss defeated flag")
