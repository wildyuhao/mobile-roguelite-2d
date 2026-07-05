extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/weapons/projectile.gd"):
		runner.assert_true(false, "projectile script should exist")
		return

	var projectile_script = load("res://scripts/weapons/projectile.gd")
	var projectile = projectile_script.new()
	var event := {
		"damage": 9,
		"projectile_speed": 440,
		"pierce": 1,
		"area_size": 72,
		"range": 360,
	}

	if projectile.has_method("configure_from_event"):
		projectile.configure_from_event(Vector2.RIGHT, event)
		runner.assert_eq(projectile.damage, 9, "projectile event damage applies")
		runner.assert_near(projectile.velocity.length(), 440.0, 0.01, "projectile event speed applies")
		runner.assert_eq(projectile.remaining_pierce, 1, "projectile event pierce applies")
		runner.assert_eq(projectile.area_damage_radius, 72.0, "projectile event area size applies")
		runner.assert_eq(projectile.max_travel_distance, 360.0, "projectile event range applies")
	else:
		runner.assert_true(false, "projectile should configure itself from a weapon event")

	projectile.free()
