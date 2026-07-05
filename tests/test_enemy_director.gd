extends RefCounted

class FakeDatabase:
	extends RefCounted

	func get_wave_events() -> Array[Dictionary]:
		return []

	func get_enemy(id: String) -> Dictionary:
		return {
			"id": id,
			"behavior": "boss",
			"max_health": 1200,
			"move_speed": 70,
			"experience_value": 30,
			"material_value": 50,
		}

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/enemy_director.gd"):
		runner.assert_true(false, "enemy director script should exist")
		return
	if not ResourceLoader.exists("res://scenes/enemies/BasicDemon.tscn"):
		runner.assert_true(false, "basic enemy scene should exist")
		return

	var director_script = load("res://scripts/systems/enemy_director.gd")
	var director = director_script.new()
	var parent := Node2D.new()
	var player := Node2D.new()
	var spawned_bosses: Array[Node] = []
	parent.add_child(player)
	parent.add_child(director)
	Engine.get_main_loop().root.add_child(parent)
	director.enemy_scene = load("res://scenes/enemies/BasicDemon.tscn")
	director.configure(FakeDatabase.new(), player)

	if director.has_signal("boss_spawned"):
		director.boss_spawned.connect(func(enemy: Node) -> void: spawned_bosses.append(enemy))
	else:
		runner.assert_true(false, "enemy director should emit boss_spawned")

	director._spawn_wave({
		"enemy_id": "seal_boss",
		"spawn_count": 1,
		"is_boss": true,
	})

	runner.assert_eq(spawned_bosses.size(), 1, "enemy director should emit boss_spawned for boss waves")
	if not spawned_bosses.is_empty():
		runner.assert_eq(spawned_bosses[0].get("is_boss"), true, "spawned boss should be configured as boss")

	parent.queue_free()
