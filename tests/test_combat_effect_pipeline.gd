extends RefCounted

func run(runner) -> void:
	var pipeline_path := "res://scripts/systems/combat_effect_pipeline.gd"
	for required_path in [
		pipeline_path,
		"res://scenes/weapons/ProjectileCarrier.tscn",
		"res://scenes/weapons/AreaCarrier.tscn",
		"res://scenes/weapons/OrbitCarrier.tscn",
		"res://scenes/weapons/SummonCarrier.tscn",
	]:
		if not ResourceLoader.exists(required_path):
			runner.assert_true(false, "missing combat pipeline resource: %s" % required_path)
			return

	var root := Node2D.new()
	var pool = load("res://scripts/systems/pool_service.gd").new()
	var pipeline = load(pipeline_path).new()
	root.add_child(pool)
	root.add_child(pipeline)
	pipeline.configure(pool, root, {
		"projectile": load("res://scenes/weapons/ProjectileCarrier.tscn"),
		"area": load("res://scenes/weapons/AreaCarrier.tscn"),
		"orbit": load("res://scenes/weapons/OrbitCarrier.tscn"),
		"summon": load("res://scenes/weapons/SummonCarrier.tscn"),
	})
	pool.set_limit("projectile", 1)
	pool.set_limit("area", 2)
	pool.set_limit("orbit", 32)
	pool.set_limit("summon", 12)

	var enemy := _enemy(Vector2(100, 0))
	root.add_child(enemy)
	var empty_context := _context(root, pool, [])
	runner.assert_eq(
		pipeline.execute_request(_projectile_request(1), empty_context),
		"no_target",
		"projectile request without targets should return no_target"
	)

	var context := _context(root, pool, [enemy])
	var resolved_hits: Array[Dictionary] = []
	pipeline.hit_resolved.connect(
		func(_target: Node, result: Dictionary) -> void:
			resolved_hits.append(result)
	)
	runner.assert_eq(
		pipeline.execute_request(_projectile_request(2), context),
		"executed",
		"valid projectile request should execute"
	)
	runner.assert_eq(
		pipeline.execute_request(_projectile_request(3), context),
		"pool_queued",
		"request beyond projectile pool limit should queue"
	)
	runner.assert_eq(pipeline.get_queued_count(), 1, "pipeline should queue a capped request once")
	var projectile: Node = pool.active_by_id.values()[0]
	projectile.try_hit(enemy)
	runner.assert_eq(enemy.get_node("HealthComponent").current_health, 90, "projectile hit should resolve through pipeline")
	runner.assert_eq(resolved_hits.size(), 1, "pipeline should emit one resolved hit")
	pipeline._physics_process(0.0)
	runner.assert_eq(pipeline.get_queued_count(), 0, "released pool capacity should execute queued request")

	var area_request := _area_request(4)
	runner.assert_eq(pipeline.execute_request(area_request, context), "executed", "area request should execute")
	runner.assert_eq(enemy.get_node("HealthComponent").current_health, 86, "instant area should resolve one hit")

	pipeline.register_target(enemy)
	var status = enemy.get_node("StatusController")
	for index in range(3):
		status.apply_status(
			{ "id": "burn", "stacks": 1, "duration": 3.0 },
			{ "weapon_id": "talisman_fire" }
		)
	status.tick_statuses(0.5)
	runner.assert_eq(enemy.get_node("HealthComponent").current_health, 80, "status signal should return through hit resolver")

	runner.assert_eq(
		pipeline.execute_request(_orbit_request(5, 2), context),
		"executed",
		"orbit request should execute"
	)
	runner.assert_eq(pool.get_stats("orbit")["active"], 2, "orbit should create its requested count")
	runner.assert_eq(
		pipeline.execute_request(_orbit_request(6, 3), context),
		"executed",
		"persistent orbit should reconfigure"
	)
	runner.assert_eq(pool.get_stats("orbit")["active"], 3, "orbit reconfiguration should add only one node")
	runner.assert_eq(pool.get_stats("orbit")["created"], 3, "orbit reconfiguration should not duplicate old nodes")
	runner.assert_eq(
		pipeline.execute_request(_summon_request(7, 2), context),
		"executed",
		"summon request should execute"
	)
	runner.assert_eq(pool.get_stats("summon")["active"], 2, "summon should create its requested count")
	runner.assert_eq(
		pipeline.execute_request(_orbit_request(8, 9), context),
		"invalid_request",
		"orbit count above eight should be rejected"
	)
	runner.assert_eq(
		pipeline.execute_request(_summon_request(9, 7), context),
		"invalid_request",
		"summon count above six should be rejected"
	)
	root.free()

func _enemy(position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.global_position = position
	var health = load("res://scripts/components/health_component.gd").new()
	var status = load("res://scripts/components/status_controller.gd").new()
	health.name = "HealthComponent"
	status.name = "StatusController"
	enemy.add_child(health)
	enemy.add_child(status)
	health.configure(100)
	status.configure(false)
	return enemy

func _context(parent: Node, pool: Node, targets: Array) -> Dictionary:
	return {
		"origin": Vector2.ZERO,
		"owner": parent,
		"targets": targets,
		"pool_service": pool,
		"parent": parent,
		"run_time": 0.0,
		"aim_direction": Vector2.RIGHT,
	}

func _projectile_request(request_id: int) -> Dictionary:
	return {
		"request_id": request_id,
		"weapon_id": "flying_sword",
		"effect_id": "sword_bolt",
		"trigger": { "id": "periodic", "cooldown": 1.0 },
		"target": { "id": "nearest", "range": 320.0 },
		"carrier": { "id": "projectile", "speed": 500.0, "count": 1 },
		"hit": { "damage": 10, "knockback": 0.0, "statuses": [] },
		"visual": {},
	}

func _area_request(request_id: int) -> Dictionary:
	return {
		"request_id": request_id,
		"weapon_id": "demon_sealing_bell",
		"effect_id": "bell_wave",
		"trigger": { "id": "periodic", "cooldown": 2.0 },
		"target": { "id": "self", "range": 150.0 },
		"carrier": { "id": "area", "radius": 150.0, "duration": 0.0, "hit_interval": 0.5, "count": 1 },
		"hit": { "damage": 4, "knockback": 0.0, "statuses": [] },
		"visual": {},
	}

func _orbit_request(request_id: int, count: int) -> Dictionary:
	return {
		"request_id": request_id,
		"weapon_id": "sword_gourd_blades",
		"effect_id": "orbit_blades",
		"trigger": { "id": "persistent" },
		"target": { "id": "self" },
		"carrier": {
			"id": "orbit",
			"count": count,
			"radius": 80.0,
			"angular_speed": 2.4,
			"hit_interval": 0.5,
		},
		"hit": { "damage": 7, "statuses": [] },
		"visual": {},
	}

func _summon_request(request_id: int, count: int) -> Dictionary:
	return {
		"request_id": request_id,
		"weapon_id": "soul_lantern",
		"effect_id": "soul_flame",
		"trigger": { "id": "periodic", "cooldown": 2.4 },
		"target": { "id": "nearest", "range": 400.0 },
		"carrier": {
			"id": "summon",
			"count": count,
			"lifetime": 6.0,
			"move_speed": 190.0,
			"attack_interval": 0.8,
			"attack_range": 48.0,
		},
		"hit": { "damage": 5, "statuses": [] },
		"visual": {},
	}
