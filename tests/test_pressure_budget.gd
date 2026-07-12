extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/pressure_budget.gd"):
		runner.assert_true(false, "pressure budget should exist")
		return
	var script = load("res://scripts/systems/pressure_budget.gd")
	var budget = script.new()
	runner.assert_eq(budget.get_budget(0.0), 14, "opening budget should be fourteen")
	runner.assert_eq(budget.get_budget(120.0), 20, "budget should rise by three per minute")
	budget.set_performance_factor(1.0)
	runner.assert_eq(
		budget.get_budget(120.0),
		23,
		"positive adjustment should cap at fifteen percent"
	)
	budget.notify_heavy_damage()
	runner.assert_eq(
		budget.get_budget(120.0),
		20,
		"recovery should suppress positive adjustment"
	)
	budget.tick(8.0)
	runner.assert_eq(
		budget.get_budget(120.0),
		23,
		"adjustment should resume after recovery"
	)
	var enemies := {
		"basic": {"role": "swarm"},
		"ranged": {"role": "ranged"},
		"control": {"role": "control"},
	}
	var ranged_card := {"groups": [{"enemy_id": "ranged", "count": 4}]}
	runner.assert_true(
		not budget.can_schedule(ranged_card, enemies, {"ranged": 2}, 8, 140),
		"ranged ratio should stay at or below thirty-five percent"
	)
	var control_card := {"groups": [{"enemy_id": "control", "count": 1}]}
	runner.assert_true(
		not budget.can_schedule(control_card, enemies, {"control": 2}, 10, 140),
		"control count should stay at two"
	)
	var swarm_card := {"groups": [{"enemy_id": "basic", "count": 6}]}
	runner.assert_true(
		not budget.can_schedule(swarm_card, enemies, {}, 138, 140),
		"active cap should reject oversized encounters"
	)
