extends CharacterBody2D
class_name EnemyAgent

signal defeated(payload: Dictionary)

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var move_speed: float = 110.0
@export var charge_speed: float = 240.0
@export var preferred_range: float = 300.0
@export var contact_damage: int = 8
@export var experience_value: int = 1
@export var material_value: int = 1
@export var is_boss: bool = false

@onready var health: Node = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var target: Node2D
var behavior: String = "chase"

func configure(definition: Dictionary, new_target: Node2D) -> void:
	if health == null:
		health = get_node_or_null("HealthComponent")
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	target = new_target
	behavior = definition.get("behavior", "chase")
	move_speed = float(definition.get("move_speed", move_speed))
	charge_speed = float(definition.get("charge_speed", charge_speed))
	preferred_range = float(definition.get("preferred_range", preferred_range))
	contact_damage = int(definition.get("contact_damage", contact_damage))
	experience_value = int(definition.get("experience_value", experience_value))
	material_value = int(definition.get("material_value", material_value))
	is_boss = definition.get("behavior", "") == "boss" or bool(definition.get("is_boss", false))
	if health != null:
		health.configure(int(definition.get("max_health", 24)))
	_configure_sprite(definition)
	_configure_collision(definition)

func _ready() -> void:
	add_to_group(GameConstantsScript.ENEMY_GROUP)
	health.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
	velocity = calculate_desired_velocity(_delta)
	move_and_slide()
	try_apply_contact_damage()

func calculate_desired_velocity(_delta: float) -> Vector2:
	if target == null:
		return Vector2.ZERO

	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return Vector2.ZERO

	match behavior:
		"charge":
			return to_target.normalized() * charge_speed
		"ranged":
			var distance := to_target.length()
			var tolerance := 24.0
			if distance < preferred_range - tolerance:
				return -to_target.normalized() * move_speed
			if distance > preferred_range + tolerance:
				return to_target.normalized() * move_speed
			return Vector2.ZERO
		_:
			return to_target.normalized() * move_speed

func _on_died() -> void:
	defeated.emit(get_defeat_payload())
	queue_free()

func get_defeat_payload() -> Dictionary:
	return {
		"enemy_position": global_position,
		"experience_value": experience_value,
		"material_value": material_value,
		"is_boss": is_boss,
	}

func _configure_sprite(definition: Dictionary) -> void:
	if sprite == null:
		return

	var sprite_path: String = definition.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)

	var sprite_scale := float(definition.get("sprite_scale", 0.0))
	if sprite_scale > 0.0:
		sprite.scale = Vector2(sprite_scale, sprite_scale)

func _configure_collision(definition: Dictionary) -> void:
	if collision_shape == null:
		return

	var collision_radius := float(definition.get("collision_radius", 0.0))
	if collision_radius <= 0.0:
		return

	var circle_shape: CircleShape2D
	if collision_shape.shape is CircleShape2D:
		circle_shape = (collision_shape.shape as CircleShape2D).duplicate()
	else:
		circle_shape = CircleShape2D.new()
	circle_shape.radius = collision_radius
	collision_shape.shape = circle_shape

func try_apply_contact_damage() -> bool:
	if target == null or not target.has_method("take_contact_damage"):
		return false
	if not target is Node2D:
		return false

	var target_node := target as Node2D
	var contact_range := get_contact_radius() + _get_target_contact_radius(target_node)
	if global_position.distance_to(target_node.global_position) > contact_range:
		return false

	return bool(target_node.call("take_contact_damage", contact_damage))

func get_contact_radius() -> float:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return 16.0

func _get_target_contact_radius(target_node: Node2D) -> float:
	if target_node.has_method("get_contact_radius"):
		return float(target_node.call("get_contact_radius"))
	return 18.0
