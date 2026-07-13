extends CharacterBody2D
class_name PlayerController

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var move_speed: float = 260.0
@export var base_max_health: int = 100
@export var contact_invulnerability_seconds: float = 0.6
@export var starting_ward_seconds: float = 6.0

@onready var health: Node = $HealthComponent
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_controller: Node = get_node_or_null("DirectionalAnimation")
@onready var hit_feedback: Node = get_node_or_null("HitFeedback")

var external_move_vector: Vector2 = Vector2.ZERO
var damage_invulnerability_remaining: float = 0.0
var starting_ward_remaining: float = 0.0
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
	_connect_hit_feedback()
	start_starting_ward()

func _physics_process(delta: float) -> void:
	tick_starting_ward(delta)
	tick_damage_invulnerability(delta)
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
	if health != null and health.has_method("set_max_health"):
		health.set_max_health(
			base_max_health + int(modifiers.get("max_health", 0))
		)

func take_contact_damage(amount: int) -> bool:
	if amount <= 0 or is_starting_ward_active() or damage_invulnerability_remaining > 0.0:
		return false
	if health == null:
		health = get_node_or_null("HealthComponent")
	if health == null or (health.has_method("is_dead") and health.is_dead()):
		return false

	health.take_damage(amount)
	damage_invulnerability_remaining = contact_invulnerability_seconds
	return true

func start_starting_ward() -> void:
	starting_ward_remaining = maxf(0.0, starting_ward_seconds)

func tick_starting_ward(delta: float) -> void:
	starting_ward_remaining = maxf(
		0.0,
		starting_ward_remaining - maxf(0.0, delta)
	)

func is_starting_ward_active() -> bool:
	return starting_ward_remaining > 0.0

func get_starting_ward_ratio() -> float:
	if starting_ward_seconds <= 0.0:
		return 0.0
	return clampf(
		starting_ward_remaining / starting_ward_seconds,
		0.0,
		1.0
	)

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

func _connect_hit_feedback() -> void:
	if health == null:
		return
	var damaged_callback := Callable(self, "_on_health_damaged")
	if health.has_signal("damaged") and not health.is_connected("damaged", damaged_callback):
		health.connect("damaged", damaged_callback)
	var died_callback := Callable(self, "_on_health_died")
	if health.has_signal("died") and not health.is_connected("died", died_callback):
		health.connect("died", died_callback)

func _on_health_damaged(amount: int) -> void:
	if hit_feedback != null and hit_feedback.has_method("play_hit"):
		hit_feedback.play_hit(amount, &"player")

func _on_health_died() -> void:
	if hit_feedback != null and hit_feedback.has_method("reset_feedback"):
		hit_feedback.reset_feedback()
