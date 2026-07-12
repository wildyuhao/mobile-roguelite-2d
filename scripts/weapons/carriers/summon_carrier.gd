extends Node2D
class_name SummonCarrier

signal hit_requested(target: Node, packet: Dictionary)
signal release_requested(node: Node)

var request: Dictionary = {}
var source_owner: Node2D
var candidates: Array = []
var current_target: Node2D
var remaining_lifetime: float = 0.0
var move_speed: float = 190.0
var attack_interval: float = 0.8
var attack_range: float = 48.0
var attack_remaining: float = 0.0
var pool_active: bool = true
var base_texture: Texture2D
var base_scale := Vector2.ONE
var base_visual_captured: bool = false

func _ready() -> void:
	_capture_base_visual()

func configure_from_request(
	new_request: Dictionary,
	new_owner: Node,
	spawn_position: Vector2
) -> void:
	request = new_request.duplicate(true)
	source_owner = new_owner as Node2D
	global_position = spawn_position
	var carrier: Dictionary = request.get("carrier", {})
	remaining_lifetime = maxf(0.05, float(carrier.get("lifetime", 6.0)))
	move_speed = maxf(0.0, float(carrier.get("move_speed", 190.0)))
	attack_interval = maxf(0.1, float(carrier.get("attack_interval", 0.8)))
	attack_range = maxf(1.0, float(carrier.get("attack_range", 48.0)))
	attack_remaining = 0.0
	_configure_visual()

func update_context(new_candidates: Array) -> void:
	candidates = new_candidates.duplicate()
	if not _is_valid_target(current_target):
		current_target = _find_nearest_target()

func _physics_process(delta: float) -> void:
	if not pool_active:
		return
	var safe_delta := maxf(0.0, delta)
	remaining_lifetime -= safe_delta
	if remaining_lifetime <= 0.0:
		_release_or_free()
		return
	if not _is_valid_target(current_target):
		current_target = _find_nearest_target()
	if current_target == null:
		return
	var offset := current_target.global_position - global_position
	if offset.length() > attack_range:
		var step := minf(move_speed * safe_delta, offset.length())
		global_position += offset.normalized() * step
		return
	attack_remaining -= safe_delta
	if attack_remaining <= 0.0:
		hit_requested.emit(current_target, _build_hit_packet())
		attack_remaining += attack_interval

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	request.clear()
	source_owner = null
	candidates.clear()
	current_target = null
	remaining_lifetime = 0.0
	move_speed = 190.0
	attack_interval = 0.8
	attack_range = 48.0
	attack_remaining = 0.0
	_restore_visual()

func deactivate_for_pool() -> void:
	begin_pool_release()
	process_mode = Node.PROCESS_MODE_DISABLED

func begin_pool_release() -> void:
	pool_active = false
	visible = false
	request.clear()
	source_owner = null
	candidates.clear()
	current_target = null
	attack_remaining = 0.0

func is_pool_active() -> bool:
	return pool_active

func _find_nearest_target() -> Node2D:
	var selected: Node2D = null
	var selected_distance := INF
	for candidate in candidates:
		if not _is_valid_target(candidate):
			continue
		var node := candidate as Node2D
		var distance := global_position.distance_to(node.global_position)
		if distance < selected_distance:
			selected = node
			selected_distance = distance
	return selected

func _is_valid_target(target: Variant) -> bool:
	if not is_instance_valid(target):
		return false
	if not target is Node2D:
		return false
	var node := target as Node2D
	if node.has_method("is_pool_active") and not bool(node.call("is_pool_active")):
		return false
	var health := node.get_node_or_null("HealthComponent")
	return health == null or not health.has_method("is_dead") or not bool(health.call("is_dead"))

func _build_hit_packet() -> Dictionary:
	var hit: Dictionary = request.get("hit", {})
	return {
		"source_weapon_id": String(request.get("weapon_id", "")),
		"source_instance_id": source_owner.get_instance_id() if source_owner != null else 0,
		"base_damage": int(hit.get("damage", 0)),
		"damage_tags": ["direct", "summon"],
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
	var scale_value := float(carrier.get("scale", 0.1))
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
