extends RefCounted

class FakeDatabase:
	extends RefCounted

	var events: Array[Dictionary] = []
	var encounters: Array[Dictionary] = []
	var formations: Dictionary = {
		"surround_gap": {
			"id": "surround_gap",
			"pattern": "ring_gap",
			"gap_degrees": 70.0,
		},
	}
	var enemies: Dictionary = {
		"basic_demon": {
			"id": "basic_demon",
			"role": "swarm",
			"behavior": "chase",
			"max_health": 24,
			"move_speed": 70,
			"experience_value": 1,
			"material_value": 1,
		},
		"seal_boss": {
			"id": "seal_boss",
			"role": "boss",
			"behavior": "boss",
			"max_health": 1200,
			"move_speed": 70,
			"experience_value": 30,
			"material_value": 50,
		},
	}

	func _init(
		new_events: Array[Dictionary] = [],
		new_encounters: Array[Dictionary] = []
	) -> void:
		events = new_events
		encounters = new_encounters

	func get_wave_events() -> Array[Dictionary]:
		return events

	func get_enemy(id: String) -> Dictionary:
		return enemies.get(id, {})

	func get_enemies() -> Dictionary:
		return enemies

	func get_encounters() -> Array[Dictionary]:
		return encounters

	func get_formations() -> Dictionary:
		return formations

class FakePoolService:
	extends Node

	var calls: Array[String] = []

	func acquire(pool_key: String, scene: PackedScene, parent: Node) -> Node:
		calls.append(pool_key)
		var node = scene.instantiate()
		parent.add_child(node)
		if node.has_method("activate_from_pool"):
			node.activate_from_pool()
		return node

	func prewarm(
		_pool_key: String,
		_scene: PackedScene,
		_parent: Node,
		count: int
	) -> int:
		return count

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
	_assert_budgeted_encounter(runner, director_script)
	_assert_allowed_encounters_and_seed(runner, director_script)
	_assert_empty_field_recovery(runner, director_script)

func _method_argument_count(instance: Object, method_name: String) -> int:
	for method in instance.get_method_list():
		if String(method.get("name", "")) == method_name:
			return Array(method.get("args", [])).size()
	return 0

func _assert_allowed_encounters_and_seed(runner, director_script) -> void:
	var director = director_script.new()
	var player := Node2D.new()
	var encounters: Array[Dictionary] = [
		{"id": "allowed_alpha", "weight": 1, "groups": []},
		{"id": "blocked_card", "weight": 1, "groups": []},
		{"id": "allowed_beta", "weight": 1, "groups": []},
	]
	var allowed_ids := ["allowed_alpha", "allowed_beta"]
	var supports_selection := _method_argument_count(director, "configure") >= 4
	runner.assert_true(
		supports_selection,
		"enemy director configure should accept encounter allowlist and explicit seed"
	)
	if supports_selection:
		director.configure(FakeDatabase.new([], encounters), player, allowed_ids, 24680)
	else:
		director.configure(FakeDatabase.new([], encounters), player)
	runner.assert_eq(
		director.encounter_seed,
		24680,
		"enemy director should retain the explicit mission seed"
	)
	runner.assert_eq(
		director.encounter_bag.rng.seed,
		24680,
		"encounter bag should use the explicit mission seed"
	)
	for card in director.encounter_bag.cards:
		runner.assert_true(
			allowed_ids.has(String(card.get("id", ""))),
			"encounter bag should contain only allowlisted cards"
		)
	runner.assert_eq(
		director.encounter_bag.cards.size(),
		2,
		"encounter bag should retain both allowlisted encounter cards"
	)
	director.free()
	player.free()

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

func _assert_budgeted_encounter(runner, director_script) -> void:
	var parent := Node2D.new()
	var player := Node2D.new()
	var director = director_script.new()
	var fake_pool := FakePoolService.new()
	var spawned_enemies: Array[Node] = []
	var started: Array[String] = []
	parent.add_child(player)
	parent.add_child(director)
	parent.add_child(fake_pool)
	Engine.get_main_loop().root.add_child(parent)
	director.enemy_scene = load("res://scenes/enemies/BasicDemon.tscn")
	if director.has_method("set_pool_service"):
		director.set_pool_service(fake_pool)
	else:
		runner.assert_true(false, "enemy director should accept a pool service")
		parent.queue_free()
		return
	director.configure(FakeDatabase.new([], [{
		"id": "test_surround",
		"weight": 1,
		"min_time": 45.0,
		"max_time": 300.0,
		"cooldown_draws": 0,
		"pressure_cost": 10,
		"formation_id": "surround_gap",
		"groups": [{"enemy_id": "basic_demon", "count": 10}],
	}]), player)
	director.enemy_spawned.connect(
		func(enemy: Node) -> void: spawned_enemies.append(enemy)
	)
	if not director.has_signal("encounter_started"):
		runner.assert_true(false, "enemy director should emit encounter_started")
		parent.queue_free()
		return
	director.encounter_started.connect(
		func(id: String) -> void: started.append(id)
	)
	director.next_encounter_time = 45.0
	director._process(45.0)
	runner.assert_eq(
		started,
		["test_surround"],
		"director should schedule an eligible encounter"
	)
	runner.assert_true(
		director.pending_spawn_waves.size() > 0,
		"encounter should enter the spawn queue"
	)
	director._process(0.0)
	runner.assert_true(
		spawned_enemies.size() > 0,
		"queued encounter should begin spawning"
	)
	runner.assert_true(
		spawned_enemies.size() <= 6,
		"one frame should respect the spawn burst cap"
	)
	var snapshot: Dictionary = director._get_active_snapshot()
	runner.assert_eq(
		snapshot.get("total", -1),
		spawned_enemies.size(),
		"director should track every active enemy it spawned"
	)
	for enemy in spawned_enemies:
			runner.assert_true(
				enemy.has_meta("encounter_id"),
				"director enemy should record encounter provenance"
			)
	runner.assert_true(fake_pool.calls.has("enemy"), "director should acquire enemies from the pool")
	parent.queue_free()

func _assert_empty_field_recovery(runner, director_script) -> void:
	var parent := Node2D.new()
	var player := Node2D.new()
	var director = director_script.new()
	parent.add_child(player)
	parent.add_child(director)
	Engine.get_main_loop().root.add_child(parent)
	director.enemy_scene = load("res://scenes/enemies/BasicDemon.tscn")
	director.configure(FakeDatabase.new([], [{
		"id": "recovery_wave",
		"weight": 1,
		"min_time": 0.0,
		"max_time": 999.0,
		"cooldown_draws": 0,
		"pressure_cost": 1,
		"formation_id": "surround_gap",
		"groups": [{"enemy_id": "basic_demon", "count": 4}],
	}]), player)
	director.next_encounter_time = 999.0
	director._process(6.0)
	runner.assert_true(
		director.pending_spawn_waves.size() > 0,
		"an empty battlefield should schedule a recovery encounter within six seconds"
	)
	parent.queue_free()
