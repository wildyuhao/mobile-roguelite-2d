extends SceneTree

const TestRunnerScript = preload("res://scripts/core/test_runner.gd")

const TEST_SCRIPTS := [
	"res://tests/test_game_database.gd",
	"res://tests/test_health_component.gd",
	"res://tests/test_upgrade_system.gd",
	"res://tests/test_weapon_system.gd",
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
