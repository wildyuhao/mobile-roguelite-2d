extends CharacterBody2D
class_name EnemyAgent

signal defeated(enemy_position: Vector2, experience_value: int)

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var move_speed: float = 110.0
@export var contact_damage: int = 8
@export var experience_value: int = 1

@onready var health: Node = $HealthComponent

var target: Node2D

func configure(definition: Dictionary, new_target: Node2D) -> void:
	target = new_target
	move_speed = float(definition.get("move_speed", move_speed))
	contact_damage = int(definition.get("contact_damage", contact_damage))
	experience_value = int(definition.get("experience_value", experience_value))
	health.configure(int(definition.get("max_health", 24)))

func _ready() -> void:
	add_to_group(GameConstantsScript.ENEMY_GROUP)
	health.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(target.global_position) * move_speed
	move_and_slide()

func _on_died() -> void:
	defeated.emit(global_position, experience_value)
	queue_free()
