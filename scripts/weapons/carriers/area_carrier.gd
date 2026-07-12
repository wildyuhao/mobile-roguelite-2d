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

func _release_or_free() -> void:
	if not pool_active:
		return
	begin_pool_release()
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)
