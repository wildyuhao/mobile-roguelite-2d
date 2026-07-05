extends Node
class_name EnemyDirector

signal enemy_spawned(enemy: Node)

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 520.0

var database
var player: Node2D
var elapsed: float = 0.0
var wave_events: Array[Dictionary] = []
var triggered_events: Dictionary = {}

func configure(new_database, new_player: Node2D) -> void:
	database = new_database
	player = new_player
	wave_events = database.get_wave_events()

func _process(delta: float) -> void:
	if database == null or player == null or enemy_scene == null:
		return

	elapsed += delta
	for event in wave_events:
		var event_time := float(event.get("time", 0.0))
		if elapsed >= event_time and not triggered_events.has(event_time):
			triggered_events[event_time] = true
			_spawn_wave(event)

func _spawn_wave(event: Dictionary) -> void:
	var enemy_id: String = event.get("enemy_id", "basic_demon")
	var definition: Dictionary = database.get_enemy(enemy_id)
	var count := int(event.get("spawn_count", 1))
	for index in range(count):
		var enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = player.global_position + Vector2.RIGHT.rotated(TAU * float(index) / max(1, count)) * spawn_radius
		enemy.configure(definition, player)
		enemy_spawned.emit(enemy)
