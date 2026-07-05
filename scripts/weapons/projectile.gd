extends Area2D
class_name Projectile

const GameConstantsScript = preload("res://scripts/core/constants.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var remaining_lifetime: float = 1.5

func configure(direction: Vector2, speed: float, new_damage: int) -> void:
	velocity = direction.normalized() * speed
	damage = new_damage
	rotation = velocity.angle()

func _ready() -> void:
	add_to_group(GameConstantsScript.PROJECTILE_GROUP)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	_damage_if_possible(parent)

func _on_body_entered(body: Node) -> void:
	_damage_if_possible(body)

func _damage_if_possible(target_node: Node) -> void:
	if target_node == null or not target_node.is_in_group(GameConstantsScript.ENEMY_GROUP):
		return

	var target_health := target_node.get_node_or_null("HealthComponent")
	if target_health != null and target_health.has_method("take_damage"):
		target_health.take_damage(damage)
		queue_free()
