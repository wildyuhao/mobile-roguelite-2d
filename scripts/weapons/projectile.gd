extends Area2D
class_name Projectile

signal release_requested(node: Node)

const GameConstantsScript = preload("res://scripts/core/constants.gd")

var velocity: Vector2 = Vector2.ZERO
var damage: int = 1
var remaining_lifetime: float = 1.5
var remaining_pierce: int = 0
var area_damage_radius: float = 0.0
var max_travel_distance: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var hit_targets: Dictionary = {}
var pool_active: bool = true
var base_visual_captured: bool = false
var base_texture: Texture2D
var base_sprite_scale: Vector2 = Vector2.ONE

func configure(direction: Vector2, speed: float, new_damage: int) -> void:
	velocity = direction.normalized() * speed
	damage = new_damage
	start_position = global_position
	rotation = velocity.angle()

func configure_from_event(direction: Vector2, event: Dictionary) -> void:
	_capture_base_visual()
	configure(direction, float(event.get("projectile_speed", 480.0)), int(event.get("damage", 1)))
	remaining_pierce = int(event.get("pierce", 0))
	area_damage_radius = float(event.get("area_size", 0.0))
	max_travel_distance = float(event.get("range", 0.0))
	_configure_visual(event)

func _configure_visual(event: Dictionary) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var texture_path := String(event.get("projectile_texture_path", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	var visual_scale: float = maxf(0.01, float(event.get("projectile_scale", 0.08)))
	sprite.scale = Vector2(visual_scale, visual_scale)
	var tint_text := String(event.get("projectile_tint", "#ffffff"))
	if Color.html_is_valid(tint_text):
		sprite.modulate = Color.html(tint_text)

func _ready() -> void:
	add_to_group(GameConstantsScript.PROJECTILE_GROUP)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_capture_base_visual()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0 or _has_reached_max_range():
		_release_or_free()

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
		_release_or_free()
		return

	_damage_node(target_node)
	if remaining_pierce <= 0:
		_release_or_free()
	else:
		remaining_pierce -= 1

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	velocity = Vector2.ZERO
	damage = 1
	remaining_lifetime = 1.5
	remaining_pierce = 0
	area_damage_radius = 0.0
	max_travel_distance = 0.0
	start_position = global_position
	rotation = 0.0
	hit_targets.clear()
	if not is_in_group(GameConstantsScript.PROJECTILE_GROUP):
		add_to_group(GameConstantsScript.PROJECTILE_GROUP)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", false)
	_capture_base_visual()
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = base_texture
		sprite.scale = base_sprite_scale
		sprite.modulate = Color.WHITE

func deactivate_for_pool() -> void:
	pool_active = false
	velocity = Vector2.ZERO
	hit_targets.clear()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(GameConstantsScript.PROJECTILE_GROUP)
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)

func _release_or_free() -> void:
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)

func _capture_base_visual() -> void:
	if base_visual_captured:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	base_texture = sprite.texture
	base_sprite_scale = sprite.scale
	base_visual_captured = true

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
