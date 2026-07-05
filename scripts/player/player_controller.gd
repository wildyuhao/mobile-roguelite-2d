extends CharacterBody2D
class_name PlayerController

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var move_speed: float = 260.0

@onready var health: Node = $HealthComponent

func _ready() -> void:
	add_to_group(GameConstantsScript.PLAYER_GROUP)
	health.configure(100)

func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	velocity = input_vector * move_speed
	move_and_slide()
