extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/weapons/projectile.gd"):
		runner.assert_true(false, "projectile script should exist")
		return

	var projectile_script = load("res://scripts/weapons/projectile.gd")
	var projectile = projectile_script.new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	projectile.add_child(sprite)
	var event := {
		"damage": 9,
		"projectile_speed": 440,
		"pierce": 1,
		"area_size": 72,
		"range": 360,
		"projectile_texture_path": "res://art/weapons/flying_sword/flying_sword_projectile.png",
		"projectile_scale": 0.12,
		"projectile_tint": "#d8b4ff",
	}

	if projectile.has_method("configure_from_event"):
		projectile.configure_from_event(Vector2.RIGHT, event)
		runner.assert_eq(projectile.damage, 9, "projectile event damage applies")
		runner.assert_near(projectile.velocity.length(), 440.0, 0.01, "projectile event speed applies")
		runner.assert_eq(projectile.remaining_pierce, 1, "projectile event pierce applies")
		runner.assert_eq(projectile.area_damage_radius, 72.0, "projectile event area size applies")
		runner.assert_eq(projectile.max_travel_distance, 360.0, "projectile event range applies")
		runner.assert_true(sprite.texture != null, "projectile event should load its visual texture")
		if sprite.texture != null:
			runner.assert_eq(sprite.texture.resource_path, "res://art/weapons/flying_sword/flying_sword_projectile.png", "projectile event should select its texture")
		runner.assert_eq(sprite.scale, Vector2(0.12, 0.12), "projectile event should select its visual scale")
		runner.assert_eq(sprite.modulate, Color.html("#d8b4ff"), "projectile event should apply its tint")
	else:
		runner.assert_true(false, "projectile should configure itself from a weapon event")

	if projectile.has_signal("release_requested") and projectile.has_method("deactivate_for_pool"):
		projectile.hit_targets[42] = true
		projectile.remaining_lifetime = 0.2
		projectile.deactivate_for_pool()
		projectile.activate_from_pool()
		projectile.configure(Vector2.DOWN, 300.0, 4)
		runner.assert_eq(projectile.remaining_pierce, 0, "reused projectile should reset pierce")
		runner.assert_eq(projectile.area_damage_radius, 0.0, "reused projectile should reset area damage")
		runner.assert_eq(projectile.max_travel_distance, 0.0, "reused projectile should reset range")
		runner.assert_eq(projectile.remaining_lifetime, 1.5, "reused projectile should reset lifetime")
		runner.assert_true(projectile.hit_targets.is_empty(), "reused projectile should clear hit targets")
		runner.assert_eq(sprite.scale, Vector2.ONE, "reused projectile should restore base visual scale")
		runner.assert_eq(sprite.modulate, Color.WHITE, "reused projectile should clear visual tint")
		var release_requests: Array[Node] = []
		projectile.release_requested.connect(
			func(node: Node) -> void: release_requests.append(node)
		)
		projectile._physics_process(2.0)
		runner.assert_eq(
			release_requests,
			[projectile],
			"expired pooled projectile should request release once"
		)
	else:
		runner.assert_true(false, "projectile should expose a pool lifecycle")

	projectile.free()
