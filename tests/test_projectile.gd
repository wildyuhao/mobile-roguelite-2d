extends RefCounted

func run(runner) -> void:
	runner.assert_true(
		not FileAccess.file_exists("res://scripts/weapons/projectile.gd"),
		"legacy projectile script should be removed after carrier migration"
	)
	var script_path := "res://scripts/weapons/carriers/projectile_carrier.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "projectile carrier script should exist")
		return

	var projectile = load(script_path).new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	projectile.add_child(sprite)
	var request := {
		"weapon_id": "flying_sword",
		"effect_id": "sword_bolt",
		"target": { "id": "nearest", "range": 360.0 },
		"carrier": { "id": "projectile", "speed": 440.0, "pierce": 1 },
		"hit": { "damage": 9, "statuses": [] },
		"visual": {
			"carrier": "res://art/weapons/flying_sword/flying_sword_projectile.png",
		},
	}
	projectile.activate_from_pool()
	projectile.configure_from_request(Vector2.RIGHT, request, null)
	runner.assert_near(projectile.velocity.length(), 440.0, 0.01, "projectile speed should apply")
	runner.assert_eq(projectile.remaining_pierce, 1, "projectile pierce should apply")
	runner.assert_eq(projectile.max_travel_distance, 360.0, "projectile range should apply")
	runner.assert_true(sprite.texture != null, "projectile should load its production texture")

	var target := Node2D.new()
	var health = load("res://scripts/components/health_component.gd").new()
	health.name = "HealthComponent"
	target.add_child(health)
	health.configure(100)
	var packets: Array[Dictionary] = []
	projectile.hit_requested.connect(
		func(_target: Node, packet: Dictionary) -> void:
			packets.append(packet)
	)
	projectile.try_hit(target)
	runner.assert_eq(packets.size(), 1, "projectile should emit one hit packet")
	runner.assert_eq(packets[0]["base_damage"], 9, "projectile hit packet should include damage")
	runner.assert_eq(health.current_health, 100, "projectile carrier should not damage directly")

	projectile.deactivate_for_pool()
	projectile.activate_from_pool()
	runner.assert_eq(projectile.remaining_pierce, 0, "reused projectile should reset pierce")
	runner.assert_eq(projectile.max_travel_distance, 0.0, "reused projectile should reset range")
	runner.assert_true(projectile.hit_targets.is_empty(), "reused projectile should clear hit targets")
	projectile.free()
	target.free()
