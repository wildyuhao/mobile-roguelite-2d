extends CharacterBody2D
class_name PlayerController

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var move_speed: float = 260.0

@onready var health: Node = $HealthComponent

var external_move_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group(GameConstantsScript.PLAYER_GROUP)
	health.configure(100)

func _physics_process(_delta: float) -> void:
	var input_vector := _get_move_input()
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	velocity = input_vector * move_speed
	move_and_slide()

func _get_move_input() -> Vector2:
	if external_move_vector != Vector2.ZERO:
		return external_move_vector

	var action_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if action_vector != Vector2.ZERO:
		return action_vector

	var keyboard_vector := Vector2.ZERO
	keyboard_vector.x = int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	keyboard_vector.y = int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return keyboard_vector.normalized()

func set_external_move_vector(new_vector: Vector2) -> void:
	if new_vector.length() > 1.0:
		new_vector = new_vector.normalized()
	external_move_vector = new_vector
