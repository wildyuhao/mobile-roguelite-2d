extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/weapons/carriers/area_carrier.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "area carrier should exist")
		return
	var carrier = load(script_path).new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	carrier.add_child(sprite)
	var target := Node2D.new()
	var health = load("res://scripts/components/health_component.gd").new()
	health.name = "HealthComponent"
	target.add_child(health)
	health.configure(100)
	target.global_position = Vector2(20, 0)
	var hits: Array[Dictionary] = []
	carrier.hit_requested.connect(
		func(_target: Node, packet: Dictionary) -> void:
			hits.append(packet)
	)
	carrier.activate_from_pool()
	carrier.configure_from_request(
		Vector2.ZERO,
		_request(1.0),
		null
	)
	runner.assert_true(sprite.texture != null, "area carrier should load its bell-wave production visual")
	carrier.update_context([target])
	carrier.update_context([target])
	runner.assert_eq(hits.size(), 1, "area should respect per-target hit interval")
	runner.assert_eq(hits[0]["base_damage"], 7, "area should emit its configured hit packet")
	runner.assert_eq(health.current_health, 100, "area carrier should never damage health directly")
	carrier._physics_process(0.5)
	carrier.update_context([target])
	runner.assert_eq(hits.size(), 2, "area should hit again after interval")
	carrier.deactivate_for_pool()
	carrier.activate_from_pool()
	carrier.configure_from_request(Vector2.ZERO, _request(1.0), null)
	carrier.update_context([target])
	runner.assert_eq(hits.size(), 3, "pooled area should clear old target cooldowns")
	carrier.free()
	target.free()

func _request(duration: float) -> Dictionary:
	return {
		"weapon_id": "demon_sealing_bell",
		"effect_id": "bell_wave",
		"target": { "id": "self", "range": 80.0 },
		"carrier": {
			"id": "area",
			"duration": duration,
			"radius": 80.0,
			"hit_interval": 0.5,
		},
		"hit": {
			"damage": 7,
			"knockback": 0.0,
			"statuses": [],
		},
		"visual": {
			"carrier": "res://art/weapons/demon_sealing_bell/bell_wave.png",
		},
	}
