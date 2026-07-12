extends SceneTree

func _initialize() -> void:
	var service = load("res://scripts/systems/pool_service.gd").new()
	root.add_child(service)
	var definitions := [
		{
			"key": "enemy",
			"scene": load("res://scenes/enemies/BasicDemon.tscn"),
			"peak": 140,
		},
		{
			"key": "projectile",
			"scene": load("res://scenes/weapons/Projectile.tscn"),
			"peak": 250,
		},
		{
			"key": "pickup",
			"scene": load("res://scenes/pickups/ExperiencePickup.tscn"),
			"peak": 100,
		},
	]
	for cycle in range(3):
		for definition in definitions:
			var nodes: Array[Node] = []
			for index in range(int(definition["peak"])):
				nodes.append(
					service.acquire(
						definition["key"],
						definition["scene"],
						root
					)
				)
			for node in nodes:
				service.release(node)

	var report: Dictionary = service.get_all_stats()
	var valid := true
	for definition in definitions:
		var stats: Dictionary = report.get(definition["key"], {})
		valid = (
			valid
			and int(stats.get("created", -1)) == int(definition["peak"])
			and int(stats.get("active", -1)) == 0
			and int(stats.get("available", -1)) == int(definition["peak"])
		)
	print(JSON.stringify(report))
	quit(0 if valid else 1)
