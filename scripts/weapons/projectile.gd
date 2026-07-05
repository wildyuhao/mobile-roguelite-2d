extends Area2D
class_name Projectile

const GameConstantsScript = preload("res://scripts/core/constants.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var remaining_lifetime: float = 1.5
var remaining_pierce: int = 0
var area_damage_radius: float = 0.0
var max_travel_distance: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var hit_targets: Dictionary = {}

func configure(direction: Vector2, speed: float, new_damage: int) -> void:
	velocity = direction.normalized() * speed
	damage = new_damage
	start_position = global_position
	rotation = velocity.angle()

func configure_from_event(direction: Vector2, event: Dictionary) -> void:
	configure(direction, float(event.get("projectile_speed", 480.0)), int(event.get("damage", 1)))
	remaining_pierce = int(event.get("pierce", 0))
	area_damage_radius = float(event.get("area_size", 0.0))
	max_travel_distance = float(event.get("range", 0.0))

func _ready() -> void:
	add_to_group(GameConstantsScript.PROJECTILE_GROUP)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0 or _has_reached_max_range():
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	_damage_if_possible(parent)

func _on_body_entered(body: Node) -> void:
	_damage_if_possible(body)

func _damage_if_possible(target_node: Node) -> void:
	if target_node == null or not target_node.is_in_group(GameConstantsScript.ENEMY_GROUP):
		return

	if hit_targets.has(target_node.get_instance_id()):
		return
	hit_targets[target_node.get_instance_id()] = true

	if area_damage_radius > 0.0:
		_damage_area(target_node.global_position)
		queue_free()
		return

	_damage_node(target_node)
	if remaining_pierce <= 0:
		queue_free()
	else:
		remaining_pierce -= 1

func _damage_area(center: Vector2) -> void:
	if get_tree() == null:
		return

	for enemy in get_tree().get_nodes_in_group(GameConstantsScript.ENEMY_GROUP):
		if enemy is Node2D and enemy.global_position.distance_to(center) <= area_damage_radius:
			_damage_node(enemy)

func _damage_node(target_node: Node) -> void:
	var target_health := target_node.get_node_or_null("HealthComponent")
	if target_health != null and target_health.has_method("take_damage"):
		target_health.take_damage(damage)

func _has_reached_max_range() -> bool:
	return max_travel_distance > 0.0 and global_position.distance_to(start_position) >= max_travel_distance
