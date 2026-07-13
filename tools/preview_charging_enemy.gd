extends Node2D

const EnemyScene = preload("res://scenes/enemies/BasicDemon.tscn")

@onready var game: Node = $Game

func _ready() -> void:
	call_deferred("_setup_preview")

func _setup_preview() -> void:
	var director: Node = game.get_node("EnemyDirector")
	director.process_mode = Node.PROCESS_MODE_DISABLED
	game.get_node("WeaponSystem").weapons.clear()
	var player: Node2D = game.get_node("Player")
	var player_health: Node = player.get_node("HealthComponent")
	player_health.configure(9999)
	game.get_node("HUD").set_health(9999, 9999)

	var definition: Dictionary = game.database.get_enemy("charging_demon").duplicate(true)
	definition["max_health"] = 9999
	var enemy = EnemyScene.instantiate()
	game.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(280, 0)
	enemy.set_meta("enemy_role", "charger")
	game._on_enemy_spawned(enemy)
	enemy.configure(definition, player)
