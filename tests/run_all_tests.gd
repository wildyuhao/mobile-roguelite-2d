extends SceneTree

const TestRunnerScript = preload("res://scripts/core/test_runner.gd")

const TEST_SCRIPTS := [
	"res://tests/test_game_database.gd",
	"res://tests/test_pool_service.gd",
	"res://tests/test_target_selector.gd",
	"res://tests/test_pool_churn.gd",
	"res://tests/test_health_component.gd",
	"res://tests/test_status_controller.gd",
	"res://tests/test_status_visual.gd",
	"res://tests/test_hit_feedback.gd",
	"res://tests/test_experience_pickup.gd",
	"res://tests/test_equipment_system.gd",
	"res://tests/test_save_system.gd",
	"res://tests/test_settlement_system.gd",
	"res://tests/test_upgrade_system.gd",
	"res://tests/test_weapon_definition_validator.gd",
	"res://tests/test_weapon_system.gd",
	"res://tests/test_weapon_simulator.gd",
	"res://tests/test_projectile.gd",
	"res://tests/test_area_carrier.gd",
	"res://tests/test_orbit_carrier.gd",
	"res://tests/test_summon_carrier.gd",
	"res://tests/test_combat_resolver.gd",
	"res://tests/test_hit_resolver.gd",
	"res://tests/test_combat_effect_pipeline.gd",
	"res://tests/test_enemy_agent.gd",
	"res://tests/test_enemy_projectile.gd",
	"res://tests/test_enemy_action_state.gd",
	"res://tests/test_contact_combat_integration.gd",
	"res://tests/test_game_loop_summary.gd",
	"res://tests/test_enemy_director.gd",
	"res://tests/test_encounter_bag.gd",
	"res://tests/test_pressure_budget.gd",
	"res://tests/test_formation_planner.gd",
	"res://tests/test_encounter_simulator.gd",
	"res://tests/test_virtual_joystick.gd",
	"res://tests/test_player_controller.gd",
	"res://tests/test_directional_animation.gd",
	"res://tests/test_starting_ward_visual.gd",
	"res://tests/test_hud.gd",
	"res://tests/test_pause_overlay.gd",
	"res://tests/test_upgrade_choice_panel.gd",
	"res://tests/test_settlement_panel.gd",
	"res://tests/test_game_scene_composition.gd",
]

func _initialize() -> void:
	var runner := TestRunnerScript.new()
	for script_path in TEST_SCRIPTS:
		if not ResourceLoader.exists(script_path):
			runner.assert_true(false, "Missing test script: %s" % script_path)
			continue

		var script = load(script_path)
		if script == null or not script.can_instantiate():
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
