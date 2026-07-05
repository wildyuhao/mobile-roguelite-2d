extends RefCounted

class FakeDatabase:
	extends RefCounted

	var events: Array[Dictionary] = []

	func _init(new_events: Array[Dictionary] = []) -> void:
		events = new_events

	func get_wave_events() -> Array[Dictionary]:
		return events

	func get_enemy(id: String) -> Dictionary:
		return {
			"id": id,
			"behavior": "chase",
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

	_assert_spawn_interval_batches_enemies(runner, director_script)

func _assert_spawn_interval_batches_enemies(runner, director_script) -> void:
	var parent := Node2D.new()
	var player := Node2D.new()
	var spawned_enemies: Array[Node] = []
	var director = director_script.new()
	parent.add_child(player)
	parent.add_child(director)
	Engine.get_main_loop().root.add_child(parent)
	director.enemy_scene = load("res://scenes/enemies/BasicDemon.tscn")
	director.configure(FakeDatabase.new([
		{
			"time": 0,
			"enemy_id": "basic_demon",
			"spawn_count": 3,
			"spawn_interval": 0.5,
		}
	]), player)
	director.enemy_spawned.connect(func(enemy: Node) -> void: spawned_enemies.append(enemy))

	director._process(0.0)
	runner.assert_eq(spawned_enemies.size(), 1, "wave should spawn one enemy immediately")

	director._process(0.49)
	runner.assert_eq(spawned_enemies.size(), 1, "wave should wait until spawn interval elapses")

	director._process(0.01)
	runner.assert_eq(spawned_enemies.size(), 2, "wave should spawn the next enemy after interval")

	director._process(0.5)
	runner.assert_eq(spawned_enemies.size(), 3, "wave should finish after repeated intervals")

	parent.queue_free()
