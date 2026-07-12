extends Area2D
class_name ProjectileCarrier

signal hit_requested(target: Node, packet: Dictionary)
signal area_requested(center: Vector2, source_request: Dictionary)
signal release_requested(node: Node)

const GameConstantsScript = preload("res://scripts/core/constants.gd")

var velocity: Vector2 = Vector2.ZERO
var remaining_lifetime: float = 1.5
var remaining_pierce: int = 0
var max_travel_distance: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var request: Dictionary = {}
var source_owner: Node
var hit_targets: Dictionary = {}
var pool_active: bool = true
var base_texture: Texture2D
var base_scale := Vector2.ONE
var base_visual_captured: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_capture_base_visual()

func configure_from_request(
	direction: Vector2,
	new_request: Dictionary,
	new_owner: Node
) -> void:
	request = new_request.duplicate(true)
	source_owner = new_owner
	var carrier: Dictionary = request.get("carrier", {})
	velocity = direction.normalized() * float(carrier.get("speed", 480.0))
	remaining_lifetime = maxf(0.05, float(carrier.get("lifetime", 1.5)))
	remaining_pierce = maxi(0, int(carrier.get("pierce", 0)))
	max_travel_distance = maxf(
		0.0,
		float(Dictionary(request.get("target", {})).get("range", 0.0))
	)
	start_position = global_position
	rotation = velocity.angle()
	_configure_visual()

func try_hit(target: Node) -> bool:
	if not pool_active or target == null or target == source_owner:
		return false
	var target_id := target.get_instance_id()
	if hit_targets.has(target_id):
		return false
	hit_targets[target_id] = true
	var hit: Dictionary = request.get("hit", {})
	if float(hit.get("splash_radius", 0.0)) > 0.0:
		var impact_position := global_position
		if target is Node2D:
			impact_position = (target as Node2D).global_position
		area_requested.emit(impact_position, request.duplicate(true))
	else:
		hit_requested.emit(target, _build_hit_packet())
	if remaining_pierce <= 0:
		_release_or_free()
	else:
		remaining_pierce -= 1
	return true

func _physics_process(delta: float) -> void:
	if not pool_active:
		return
	global_position += velocity * maxf(0.0, delta)
	remaining_lifetime -= maxf(0.0, delta)
	if (
		remaining_lifetime <= 0.0
		or (
			max_travel_distance > 0.0
			and global_position.distance_to(start_position) >= max_travel_distance
		)
	):
		_release_or_free()

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	velocity = Vector2.ZERO
	remaining_lifetime = 1.5
	remaining_pierce = 0
	max_travel_distance = 0.0
	start_position = global_position
	request.clear()
	source_owner = null
	hit_targets.clear()
	rotation = 0.0
	_restore_visual()
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", false)

func deactivate_for_pool() -> void:
	begin_pool_release()
	process_mode = Node.PROCESS_MODE_DISABLED
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", true)

func begin_pool_release() -> void:
	pool_active = false
	visible = false
	velocity = Vector2.ZERO
	request.clear()
	source_owner = null
	hit_targets.clear()

func _on_area_entered(area: Area2D) -> void:
	var candidate := area.get_parent()
	if candidate != null and candidate.is_in_group(GameConstantsScript.ENEMY_GROUP):
		try_hit(candidate)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group(GameConstantsScript.ENEMY_GROUP):
		try_hit(body)

func _build_hit_packet() -> Dictionary:
	var hit: Dictionary = request.get("hit", {})
	return {
		"source_weapon_id": String(request.get("weapon_id", "")),
		"source_instance_id": source_owner.get_instance_id() if source_owner != null else 0,
		"base_damage": int(hit.get("damage", 0)),
		"damage_tags": ["direct", "projectile"],
		"knockback": float(hit.get("knockback", 0.0)),
		"hit_position": global_position,
		"status_payloads": Array(hit.get("statuses", [])).duplicate(true),
		"hit_effect_id": String(hit.get("hit_effect_id", "")),
	}

func _release_or_free() -> void:
	if not pool_active:
		return
	begin_pool_release()
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)

func _configure_visual() -> void:
	_capture_base_visual()
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var visual: Dictionary = request.get("visual", {})
	var carrier: Dictionary = request.get("carrier", {})
	var texture_path := String(visual.get("carrier", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	var scale_value := float(visual.get("scale", carrier.get("scale", 0.08)))
	sprite.scale = Vector2.ONE * maxf(0.01, scale_value)
	var tint_text := String(visual.get("tint", carrier.get("tint", "#ffffff")))
	if Color.html_is_valid(tint_text):
		sprite.modulate = Color.html(tint_text)

func _capture_base_visual() -> void:
	if base_visual_captured:
		return
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	base_texture = sprite.texture
	base_scale = sprite.scale
	base_visual_captured = true

func _restore_visual() -> void:
	_capture_base_visual()
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.texture = base_texture
		sprite.scale = base_scale
		sprite.modulate = Color.WHITE
