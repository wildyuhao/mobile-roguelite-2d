extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/weapons/carriers/orbit_carrier.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "orbit carrier should exist")
		return
	var script = load(script_path)
	var owner := Node2D.new()
	owner.global_position = Vector2(100, 100)
	var first = script.new()
	var second = script.new()
	first.activate_from_pool()
	second.activate_from_pool()
	first.configure_from_request(0, 2, _request(), owner)
	second.configure_from_request(1, 2, _request(), owner)
	first._physics_process(0.0)
	second._physics_process(0.0)
	runner.assert_near(
		(first.global_position + second.global_position).distance_to(owner.global_position * 2.0),
		0.0,
		0.01,
		"two orbit entities should stay opposite"
	)
	owner.global_position = Vector2(160, 120)
	first._physics_process(1.0)
	second._physics_process(1.0)
	runner.assert_near(
		((first.global_position + second.global_position) * 0.5).distance_to(owner.global_position),
		0.0,
		0.01,
		"orbit entities should follow owner movement"
	)

	var target := Node2D.new()
	var health = load("res://scripts/components/health_component.gd").new()
	health.name = "HealthComponent"
	target.add_child(health)
	health.configure(100)
	target.global_position = first.global_position
	var hits: Array[Dictionary] = []
	first.hit_requested.connect(
		func(_target: Node, packet: Dictionary) -> void:
			hits.append(packet)
	)
	first.update_context([target])
	first.update_context([target])
	runner.assert_eq(hits.size(), 1, "orbit should respect per-target hit interval")
	runner.assert_eq(health.current_health, 100, "orbit should not damage health directly")
	first._physics_process(0.5)
	target.global_position = first.global_position
	first.update_context([target])
	runner.assert_eq(hits.size(), 2, "orbit should hit again after interval")
	first.deactivate_for_pool()
	first.activate_from_pool()
	first.configure_from_request(0, 2, _request(), owner)
	first._physics_process(0.0)
	target.global_position = first.global_position
	first.update_context([target])
	runner.assert_eq(hits.size(), 3, "reused orbit should clear old hit history")
	first.free()
	second.free()
	target.free()
	owner.free()

func _request() -> Dictionary:
	return {
		"weapon_id": "sword_gourd_blades",
		"effect_id": "orbit_blades",
		"target": { "id": "self" },
		"carrier": {
			"id": "orbit",
			"count": 2,
			"radius": 80.0,
			"angular_speed": 2.4,
			"hit_interval": 0.5,
			"hit_radius": 20.0,
		},
		"hit": { "damage": 7, "knockback": 0.0, "statuses": [] },
		"visual": {},
	}
