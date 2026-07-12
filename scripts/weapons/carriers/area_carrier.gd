extends Area2D
class_name AreaCarrier

signal hit_requested(target: Node, packet: Dictionary)
signal release_requested(node: Node)

var request: Dictionary = {}
var source_owner: Node
var radius: float = 0.0
var remaining_duration: float = 0.0
var hit_interval: float = 0.5
var target_cooldowns: Dictionary = {}
var pool_active: bool = true
var base_texture: Texture2D
var base_scale := Vector2.ONE
var base_visual_captured: bool = false

func _ready() -> void:
	_capture_base_visual()

func configure_from_request(
	center: Vector2,
	new_request: Dictionary,
	new_owner: Node
) -> void:
	global_position = center
	request = new_request.duplicate(true)
	source_owner = new_owner
	var carrier: Dictionary = request.get("carrier", {})
	var target_definition: Dictionary = request.get("target", {})
	var hit: Dictionary = request.get("hit", {})
	radius = maxf(
		1.0,
		float(carrier.get(
			"radius",
			hit.get("splash_radius", target_definition.get("range", 1.0))
		))
	)
	remaining_duration = maxf(0.0, float(carrier.get("duration", 0.0)))
	hit_interval = maxf(0.1, float(carrier.get("hit_interval", 0.5)))
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var shape := CircleShape2D.new()
		shape.radius = radius
		collision.shape = shape
	_configure_visual()

func update_context(candidates: Array) -> void:
	if not pool_active:
		return
	for candidate in candidates:
		if candidate is Node2D and is_instance_valid(candidate):
			var node := candidate as Node2D
			if global_position.distance_to(node.global_position) <= radius:
				try_hit(node)

func try_hit(target: Node) -> bool:
	if not pool_active or target == null or target == source_owner:
		return false
	var target_id := target.get_instance_id()
	if float(target_cooldowns.get(target_id, 0.0)) > 0.0:
		return false
	target_cooldowns[target_id] = hit_interval
	hit_requested.emit(target, _build_hit_packet())
	return true

func finish_instant() -> void:
	if remaining_duration <= 0.0:
		_release_or_free()

func _physics_process(delta: float) -> void:
	if not pool_active:
		return
	var safe_delta := maxf(0.0, delta)
	for target_id in target_cooldowns.keys():
		var remaining := float(target_cooldowns[target_id]) - safe_delta
		if remaining <= 0.0:
			target_cooldowns.erase(target_id)
		else:
			target_cooldowns[target_id] = remaining
	if remaining_duration > 0.0:
		remaining_duration -= safe_delta
		if remaining_duration <= 0.0:
			_release_or_free()

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	request.clear()
	source_owner = null
	radius = 0.0
	remaining_duration = 0.0
	hit_interval = 0.5
	target_cooldowns.clear()
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
	request.clear()
	source_owner = null
	target_cooldowns.clear()

func _build_hit_packet() -> Dictionary:
	var hit: Dictionary = request.get("hit", {})
	return {
		"source_weapon_id": String(request.get("weapon_id", "")),
		"source_instance_id": source_owner.get_instance_id() if source_owner != null else 0,
		"base_damage": int(hit.get("damage", 0)),
		"damage_tags": ["direct", "area"],
		"knockback": float(hit.get("knockback", 0.0)),
		"hit_position": global_position,
		"status_payloads": Array(hit.get("statuses", [])).duplicate(true),
		"hit_effect_id": String(hit.get("hit_effect_id", "")),
	}

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
	var scale_value := float(carrier.get("scale", radius / 128.0))
	sprite.scale = Vector2.ONE * maxf(0.01, scale_value)
	var tint_text := String(carrier.get("tint", "#ffffff"))
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

func _release_or_free() -> void:
	if not pool_active:
		return
	begin_pool_release()
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)
