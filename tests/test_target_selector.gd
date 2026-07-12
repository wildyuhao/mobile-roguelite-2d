extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/weapons/target_selector.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "target selector should exist")
		return
	var selector = load(script_path).new()
	var first := _target(Vector2(100, 0), 80, 100)
	var second := _target(Vector2(100, 0), 20, 100)
	var behind := _target(Vector2(-80, 0), 100, 100)
	var dead := _target(Vector2(10, 0), 0, 100)

	var nearest = selector.select(
		{ "id": "nearest", "range": 200.0 },
		Vector2.ZERO,
		[first, second],
		{}
	)
	runner.assert_eq(nearest["targets"][0], first, "nearest ties should preserve candidate order")
	nearest = selector.select(
		{ "id": "nearest", "range": 200.0 },
		Vector2.ZERO,
		[dead, first],
		{}
	)
	runner.assert_eq(nearest["targets"][0], first, "target selection should ignore dead candidates")

	var lowest = selector.select(
		{ "id": "lowest_health", "range": 200.0 },
		Vector2.ZERO,
		[first, second],
		{}
	)
	runner.assert_eq(lowest["targets"][0], second, "lowest health should use health ratio")

	var sector = selector.select(
		{ "id": "sector", "range": 200.0, "angle_degrees": 70.0 },
		Vector2.ZERO,
		[first, behind],
		{ "aim_direction": Vector2.RIGHT }
	)
	runner.assert_eq(sector["targets"], [first], "sector should exclude targets behind its aim")

	var radial = selector.select(
		{ "id": "radial", "range": 200.0 },
		Vector2.ZERO,
		[],
		{ "count": 4, "run_time": 0.0 }
	)
	runner.assert_eq(radial["directions"].size(), 4, "radial should create the requested direction count")
	runner.assert_near(radial["directions"][0].length(), 1.0, 0.001, "radial directions should be normalized")

	var self_selection = selector.select(
		{ "id": "self" },
		Vector2(12, 34),
		[],
		{}
	)
	runner.assert_eq(self_selection["status"], "selected", "self target should not require enemies")
	runner.assert_eq(self_selection["origin"], Vector2(12, 34), "self target should preserve origin")

	var empty = selector.select(
		{ "id": "nearest", "range": 50.0 },
		Vector2.ZERO,
		[behind],
		{}
	)
	runner.assert_eq(empty["status"], "no_target", "out-of-range targets should return no_target")
	first.free()
	second.free()
	behind.free()
	dead.free()

func _target(position: Vector2, current_health: int, max_health: int) -> Node2D:
	var node := Node2D.new()
	node.global_position = position
	var health = load("res://scripts/components/health_component.gd").new()
	health.name = "HealthComponent"
	node.add_child(health)
	health.configure(max_health)
	health.current_health = current_health
	return node
