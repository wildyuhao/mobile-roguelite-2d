extends SceneTree

const TestRunnerScript = preload("res://scripts/core/test_runner.gd")

const TEST_SCRIPTS := [
	"res://tests/test_game_database.gd",
	"res://tests/test_health_component.gd",
	"res://tests/test_experience_pickup.gd",
	"res://tests/test_equipment_system.gd",
	"res://tests/test_save_system.gd",
	"res://tests/test_settlement_system.gd",
	"res://tests/test_upgrade_system.gd",
	"res://tests/test_weapon_system.gd",
	"res://tests/test_projectile.gd",
	"res://tests/test_combat_resolver.gd",
	"res://tests/test_enemy_agent.gd",
	"res://tests/test_game_loop_summary.gd",
	"res://tests/test_enemy_director.gd",
	"res://tests/test_virtual_joystick.gd",
	"res://tests/test_player_controller.gd",
	"res://tests/test_hud.gd",
	"res://tests/test_game_scene_composition.gd",
]

func _initialize() -> void:
	var runner := TestRunnerScript.new()
	for script_path in TEST_SCRIPTS:
		if not ResourceLoader.exists(script_path):
			runner.assert_true(false, "Missing test script: %s" % script_path)
			continue

		var script = load(script_path)
		if script == null:
			runner.assert_true(false, "Test script failed to load: %s" % script_path)
			continue

		var test_case: Object = script.new()
		if not test_case.has_method("run"):
			runner.assert_true(false, "Test script has no run method: %s" % script_path)
			continue

		test_case.run(runner)

	if runner.has_failures():
		runner.print_failures()
		quit(1)
	else:
		print("All tests passed.")
		quit(0)
