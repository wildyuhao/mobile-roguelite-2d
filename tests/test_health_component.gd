extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/components/health_component.gd"):
		runner.assert_true(false, "health component script should exist")
		return

	var health_component_script = load("res://scripts/components/health_component.gd")
	var health = health_component_script.new()
	health.configure(30)

	runner.assert_eq(health.max_health, 30, "max health after configure")
	runner.assert_eq(health.current_health, 30, "current health after configure")

	health.take_damage(8)
	runner.assert_eq(health.current_health, 22, "damage reduces current health")
	runner.assert_true(not health.is_dead(), "health should not be dead yet")

	health.heal(5)
	runner.assert_eq(health.current_health, 27, "heal restores current health")

	health.take_damage(100)
	runner.assert_eq(health.current_health, 0, "damage clamps at zero")
	runner.assert_true(health.is_dead(), "health should be dead at zero")

	var scaling_health = health_component_script.new()
	scaling_health.configure(100)
	scaling_health.take_damage(40)
	if scaling_health.has_method("set_max_health"):
		scaling_health.set_max_health(120)
		runner.assert_eq(scaling_health.max_health, 120, "max health should increase")
		runner.assert_eq(
			scaling_health.current_health,
			80,
			"max health increase should grant only the added capacity"
		)
		scaling_health.set_max_health(120)
		runner.assert_eq(
			scaling_health.current_health,
			80,
			"reapplying the same max health should not heal damage"
		)
		scaling_health.set_max_health(70)
		runner.assert_eq(
			scaling_health.current_health,
			70,
			"max health reduction should only clamp current health"
		)
	else:
		runner.assert_true(false, "health should resize max health without a full refill")
	scaling_health.free()
	health.free()
