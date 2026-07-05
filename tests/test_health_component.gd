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
	health.free()
