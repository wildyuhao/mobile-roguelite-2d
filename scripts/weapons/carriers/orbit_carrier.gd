extends Area2D
class_name OrbitCarrier

signal hit_requested(target: Node, packet: Dictionary)
signal release_requested(node: Node)

var request: Dictionary = {}
var source_owner: Node2D
var orbit_index: int = 0
var orbit_count: int = 1
var radius: float = 80.0
var angular_speed: float = 2.4
var hit_interval: float = 0.5
var hit_radius: float = 20.0
var remaining_duration: float = 0.0
var elapsed: float = 0.0
var target_cooldowns: Dictionary = {}
var pool_active: bool = true
var base_texture: Texture2D
var base_scale := Vector2.ONE
var base_visual_captured: bool = false

func _ready() -> void:
	_capture_base_visual()

func configure_from_request(
	new_orbit_index: int,
	new_orbit_count: int,
	new_request: Dictionary,
	new_owner: Node
) -> void:
	orbit_index = maxi(0, new_orbit_index)
	orbit_count = maxi(1, new_orbit_count)
	request = new_request.duplicate(true)
	source_owner = new_owner as Node2D
	var carrier: Dictionary = request.get("carrier", {})
	radius = maxf(1.0, float(carrier.get("radius", 80.0)))
	angular_speed = float(carrier.get("angular_speed", 2.4))
	hit_interval = maxf(0.1, float(carrier.get("hit_interval", 0.5)))
	hit_radius = maxf(1.0, float(carrier.get("hit_radius", 20.0)))
	remaining_duration = maxf(0.0, float(carrier.get("duration", 0.0)))
	_configure_visual()
	_update_position()

func update_context(candidates: Array) -> void:
	if not pool_active:
		return
	for candidate in candidates:
		if candidate is Node2D and is_instance_valid(candidate):
			var node := candidate as Node2D
			if global_position.distance_to(node.global_position) <= hit_radius:
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

func _physics_process(delta: float) -> void:
	if not pool_active:
		return
	if source_owner == null or not is_instance_valid(source_owner):
		_release_or_free()
		return
	var safe_delta := maxf(0.0, delta)
	elapsed += safe_delta
	for target_id in target_cooldowns.keys():
		var remaining := float(target_cooldowns[target_id]) - safe_delta
		if remaining <= 0.0:
			target_cooldowns.erase(target_id)
		else:
			target_cooldowns[target_id] = remaining
	_update_position()
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
	orbit_index = 0
	orbit_count = 1
	radius = 80.0
	angular_speed = 2.4
	hit_interval = 0.5
	hit_radius = 20.0
	remaining_duration = 0.0
	elapsed = 0.0
	target_cooldowns.clear()
	_restore_visual()

func deactivate_for_pool() -> void:
	begin_pool_release()
	process_mode = Node.PROCESS_MODE_DISABLED

func begin_pool_release() -> void:
	pool_active = false
	visible = false
	request.clear()
	source_owner = null
	target_cooldowns.clear()

func is_pool_active() -> bool:
	return pool_active

func _update_position() -> void:
	if source_owner == null:
		return
	var base_angle := TAU * float(orbit_index) / float(orbit_count)
	global_position = (
		source_owner.global_position
		+ Vector2.RIGHT.rotated(base_angle + elapsed * angular_speed) * radius
	)

func _build_hit_packet() -> Dictionary:
	var hit: Dictionary = request.get("hit", {})
	return {
		"source_weapon_id": String(request.get("weapon_id", "")),
		"source_instance_id": source_owner.get_instance_id() if source_owner != null else 0,
		"base_damage": int(hit.get("damage", 0)),
		"damage_tags": ["direct", "orbit"],
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
	var scale_value := float(carrier.get("scale", 0.08))
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
