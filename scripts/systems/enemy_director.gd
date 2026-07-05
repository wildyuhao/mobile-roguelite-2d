extends Node
class_name EnemyDirector

const SPAWN_TIMER_EPSILON := 0.00001

signal enemy_spawned(enemy: Node)
signal boss_spawned(enemy: Node)

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 520.0

var database
var player: Node2D
var elapsed: float = 0.0
var wave_events: Array[Dictionary] = []
var triggered_events: Dictionary = {}
var pending_spawn_waves: Array[Dictionary] = []

func configure(new_database, new_player: Node2D) -> void:
	database = new_database
	player = new_player
	wave_events = database.get_wave_events()

func _process(delta: float) -> void:
	if database == null or player == null or enemy_scene == null:
		return

	elapsed += delta
	_process_pending_spawn_waves(delta)
	for event in wave_events:
		var event_time := float(event.get("time", 0.0))
		if elapsed >= event_time and not triggered_events.has(event_time):
			triggered_events[event_time] = true
			_spawn_wave(event)

func _spawn_wave(event: Dictionary) -> void:
	var enemy_id: String = event.get("enemy_id", "basic_demon")
	var definition: Dictionary = database.get_enemy(enemy_id).duplicate(true)
	if bool(event.get("is_boss", false)):
		definition["is_boss"] = true
	var count := int(event.get("spawn_count", 1))
	pending_spawn_waves.append({
		"definition": definition,
		"spawn_count": count,
		"spawn_interval": max(0.0, float(event.get("spawn_interval", 0.0))),
		"spawned_count": 0,
		"time_until_next_spawn": 0.0,
	})
	_process_pending_spawn_waves(0.0)

func _process_pending_spawn_waves(delta: float) -> void:
	var completed_waves: Array[Dictionary] = []
	for wave in pending_spawn_waves:
		var spawned_count := int(wave.get("spawned_count", 0))
		var spawn_count := int(wave.get("spawn_count", 1))
		var spawn_interval := float(wave.get("spawn_interval", 0.0))
		var time_until_next_spawn := float(wave.get("time_until_next_spawn", 0.0)) - delta

		if spawn_interval <= 0.0:
			while spawned_count < spawn_count:
				_spawn_enemy(wave["definition"], spawned_count, spawn_count)
				spawned_count += 1
		else:
			while spawned_count < spawn_count and time_until_next_spawn <= SPAWN_TIMER_EPSILON:
				_spawn_enemy(wave["definition"], spawned_count, spawn_count)
				spawned_count += 1
				time_until_next_spawn += spawn_interval

		wave["spawned_count"] = spawned_count
		wave["time_until_next_spawn"] = time_until_next_spawn
		if spawned_count >= spawn_count:
			completed_waves.append(wave)

	for wave in completed_waves:
		pending_spawn_waves.erase(wave)

func _spawn_enemy(definition: Dictionary, index: int, count: int) -> void:
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = player.global_position + Vector2.RIGHT.rotated(TAU * float(index) / max(1, count)) * spawn_radius
	enemy.configure(definition, player)
	enemy_spawned.emit(enemy)
	if bool(definition.get("is_boss", false)) or definition.get("behavior", "") == "boss":
		boss_spawned.emit(enemy)
