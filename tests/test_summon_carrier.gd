extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/weapons/carriers/summon_carrier.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "summon carrier should exist")
		return
	var summon = load(script_path).new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	summon.add_child(sprite)
	var owner := Node2D.new()
	var near_target := _target(Vector2(100, 0))
	var far_target := _target(Vector2(200, 0))
	var hits: Array[Node] = []
	var releases: Array[Node] = []
	summon.hit_requested.connect(
		func(target: Node, _packet: Dictionary) -> void:
			hits.append(target)
	)
	summon.release_requested.connect(
		func(node: Node) -> void:
			releases.append(node)
	)
	summon.activate_from_pool()
	summon.configure_from_request(_request(), owner, Vector2.ZERO)
	runner.assert_true(sprite.texture != null, "summon carrier should load its soul-flame production visual")
	summon.update_context([far_target, near_target])
	summon._physics_process(1.0)
	runner.assert_eq(summon.current_target, near_target, "summon should choose nearest explicit candidate")
	runner.assert_true(summon.global_position.distance_to(Vector2.ZERO) <= 50.01, "summon should not exceed move speed")
	near_target.global_position = Vector2(55, 0)
	summon.update_context([near_target, far_target])
	summon._physics_process(0.1)
	runner.assert_eq(hits, [near_target], "summon should attack once after entering range")
	summon._physics_process(0.2)
	runner.assert_eq(hits.size(), 1, "summon should respect attack interval")
	summon._physics_process(0.8)
	runner.assert_eq(hits.size(), 2, "summon should attack again after cooldown")
	near_target.free()
	summon.update_context([far_target])
	summon._physics_process(0.1)
	runner.assert_eq(summon.current_target, far_target, "summon should retarget invalid targets")
	summon._physics_process(1.0)
	runner.assert_eq(releases, [summon], "summon should release at lifetime expiry")
	summon.activate_from_pool()
	runner.assert_true(summon.current_target == null, "pooled summon should clear old target")
	summon.free()
	far_target.free()
	owner.free()

func _target(position: Vector2) -> Node2D:
	var target := Node2D.new()
	target.global_position = position
	var health = load("res://scripts/components/health_component.gd").new()
	health.name = "HealthComponent"
	target.add_child(health)
	health.configure(100)
	return target

func _request() -> Dictionary:
	return {
		"weapon_id": "soul_lantern",
		"effect_id": "soul_flame",
		"target": { "id": "nearest", "range": 400.0 },
		"carrier": {
			"id": "summon",
			"count": 1,
			"lifetime": 3.0,
			"move_speed": 50.0,
			"attack_interval": 0.8,
			"attack_range": 10.0,
		},
		"hit": { "damage": 5, "knockback": 0.0, "statuses": [] },
		"visual": {
			"carrier": "res://art/weapons/soul_lantern/soul_flame.png",
		},
	}
