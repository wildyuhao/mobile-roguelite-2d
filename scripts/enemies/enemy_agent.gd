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

var target: Node2D
var behavior: String = "chase"

func configure(definition: Dictionary, new_target: Node2D) -> void:
	if health == null:
		health = get_node_or_null("HealthComponent")
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

func _ready() -> void:
	add_to_group(GameConstantsScript.ENEMY_GROUP)
	health.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
	velocity = calculate_desired_velocity(_delta)
	move_and_slide()

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
