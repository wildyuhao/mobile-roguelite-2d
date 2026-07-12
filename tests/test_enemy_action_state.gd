extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/enemy_action_state.gd"):
		runner.assert_true(false, "enemy action state should exist")
		return
	var state_script = load("res://scripts/systems/enemy_action_state.gd")
	var state = state_script.new()
	runner.assert_eq(state.state, "locomotion", "enemy action should begin in locomotion")
	runner.assert_true(
		state.start_attack(0.3, 0.1, 0.4),
		"locomotion should start an attack"
	)
	runner.assert_eq(state.state, "windup", "attack should begin with windup")
	runner.assert_true(not state.is_damage_active(), "windup should not deal damage")
	var remaining_before_freeze := float(state.remaining)
	var tick_argument_count := _method_argument_count(state, "tick")
	runner.assert_true(tick_argument_count >= 2, "action tick should accept a time scale")
	if tick_argument_count >= 2:
		state.tick(1.0, 0.0)
		runner.assert_eq(state.state, "windup", "zero action scale should preserve windup")
		runner.assert_near(float(state.remaining), remaining_before_freeze, 0.001, "zero action scale should preserve remaining time")
	runner.assert_eq(
		state.tick(0.2).size(),
		0,
		"partial windup should not transition"
	)
	var active_transitions = state.tick(0.1)
	runner.assert_true(
		active_transitions.has("active"),
		"completed windup should enter active"
	)
	runner.assert_true(state.is_damage_active(), "active state should enable damage")
	var recovery_transitions = state.tick(0.1)
	runner.assert_true(
		recovery_transitions.has("recovery"),
		"completed active window should enter recovery"
	)
	runner.assert_true(not state.is_damage_active(), "recovery should disable damage")
	var locomotion_transitions = state.tick(0.4)
	runner.assert_true(
		locomotion_transitions.has("locomotion"),
		"completed recovery should resume locomotion"
	)
	state.mark_dead()
	runner.assert_eq(state.state, "dead", "death should override the action state")
	runner.assert_true(
		not state.start_attack(0.1, 0.1, 0.1),
		"dead enemies cannot start attacks"
	)

func _method_argument_count(instance: Object, method_name: String) -> int:
	for method in instance.get_method_list():
		if String(method.get("name", "")) == method_name:
			return Array(method.get("args", [])).size()
	return 0
