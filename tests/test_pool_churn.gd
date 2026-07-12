extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/pool_service.gd"):
		runner.assert_true(false, "pool churn requires pool service")
		return
	var parent := Node2D.new()
	var service = load("res://scripts/systems/pool_service.gd").new()
	parent.add_child(service)
	var definitions := [
		{
			"key": "enemy",
			"scene": load("res://scenes/enemies/BasicDemon.tscn"),
			"peak": 12,
		},
		{
			"key": "projectile",
			"scene": load("res://scenes/weapons/ProjectileCarrier.tscn"),
			"peak": 24,
		},
		{
			"key": "pickup",
			"scene": load("res://scenes/pickups/ExperiencePickup.tscn"),
			"peak": 16,
		},
	]
	for cycle in range(2):
		for definition in definitions:
			var nodes: Array[Node] = []
			for index in range(int(definition["peak"])):
				nodes.append(
					service.acquire(
						definition["key"],
						definition["scene"],
						parent
					)
				)
			for node in nodes:
				service.release(node)
	for definition in definitions:
		var stats: Dictionary = service.get_stats(definition["key"])
		runner.assert_eq(
			stats.get("created", -1),
			definition["peak"],
			"%s should stop creating at peak" % definition["key"]
		)
		runner.assert_eq(
			stats.get("active", -1),
			0,
			"%s should finish with no active nodes" % definition["key"]
		)
	if service.has_method("get_all_stats"):
		var all_stats: Dictionary = service.get_all_stats()
		runner.assert_eq(all_stats.size(), 3, "pool service should report every populated pool")
	else:
		runner.assert_true(false, "pool service should expose aggregate statistics")
	parent.free()
