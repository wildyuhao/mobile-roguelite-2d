extends RefCounted

func run(runner) -> void:
	var pipeline_path := "res://scripts/systems/combat_effect_pipeline.gd"
	for required_path in [
		pipeline_path,
		"res://scenes/weapons/ProjectileCarrier.tscn",
		"res://scenes/weapons/AreaCarrier.tscn",
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
	})
	pool.set_limit("projectile", 1)
	pool.set_limit("area", 2)

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
