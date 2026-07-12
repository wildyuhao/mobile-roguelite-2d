extends CharacterBody2D
class_name PlayerController

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var move_speed: float = 260.0
@export var base_max_health: int = 100
@export var contact_invulnerability_seconds: float = 0.6

@onready var health: Node = $HealthComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_controller: Node = get_node_or_null("DirectionalAnimation")

var external_move_vector: Vector2 = Vector2.ZERO
var damage_invulnerability_remaining: float = 0.0
var base_move_speed: float = 260.0

func _ready() -> void:
	add_to_group(GameConstantsScript.PLAYER_GROUP)
	base_move_speed = move_speed
	if health == null:
		health = get_node_or_null("HealthComponent")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if health != null:
		health.configure(base_max_health)

func _physics_process(_delta: float) -> void:
	tick_damage_invulnerability(_delta)
	var input_vector := _get_move_input()
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	if animation_controller != null and animation_controller.has_method("update_motion"):
		animation_controller.update_motion(input_vector)
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

func apply_stat_modifiers(modifiers: Dictionary) -> void:
	if health == null:
		health = get_node_or_null("HealthComponent")

	move_speed = base_move_speed + float(modifiers.get("move_speed", 0.0))
	if health != null and health.has_method("configure"):
		health.configure(base_max_health + int(modifiers.get("max_health", 0)))

func take_contact_damage(amount: int) -> bool:
	if amount <= 0 or damage_invulnerability_remaining > 0.0:
		return false
	if health == null:
		health = get_node_or_null("HealthComponent")
	if health == null or (health.has_method("is_dead") and health.is_dead()):
		return false

	health.take_damage(amount)
	damage_invulnerability_remaining = contact_invulnerability_seconds
	return true

func tick_damage_invulnerability(delta: float) -> void:
	if damage_invulnerability_remaining <= 0.0:
		return
	damage_invulnerability_remaining = max(0.0, damage_invulnerability_remaining - max(0.0, delta))

func get_contact_radius() -> float:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return 18.0
