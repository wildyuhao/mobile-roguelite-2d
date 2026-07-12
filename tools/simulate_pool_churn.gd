extends SceneTree

func _initialize() -> void:
	var service = load("res://scripts/systems/pool_service.gd").new()
	root.add_child(service)
	var definitions := [
		{
			"key": "projectile",
			"scene": load("res://scenes/weapons/ProjectileCarrier.tscn"),
			"peak": 250,
		},
		{
			"key": "area",
			"scene": load("res://scenes/weapons/AreaCarrier.tscn"),
			"peak": 24,
		},
		{
			"key": "orbit",
			"scene": load("res://scenes/weapons/OrbitCarrier.tscn"),
			"peak": 32,
		},
		{
			"key": "summon",
			"scene": load("res://scenes/weapons/SummonCarrier.tscn"),
			"peak": 12,
		},
	]
	for definition in definitions:
		service.set_limit(definition["key"], int(definition["peak"]))
	var valid := true
	for cycle in range(3):
		for definition in definitions:
			var nodes: Array[Node] = []
			for index in range(int(definition["peak"])):
				var node: Node = service.acquire(
					definition["key"],
					definition["scene"],
					root
				)
				if node != null:
					nodes.append(node)
			valid = valid and nodes.size() == int(definition["peak"])
			for node in nodes:
				service.release(node)

	var report: Dictionary = service.get_all_stats()
	for definition in definitions:
		var stats: Dictionary = report.get(definition["key"], {})
		valid = (
			valid
			and int(stats.get("created", -1)) == int(definition["peak"])
			and int(stats.get("active", -1)) == 0
			and int(stats.get("available", -1)) == int(stats.get("created", -2))
		)
	print(JSON.stringify(report))
	quit(0 if valid else 1)
