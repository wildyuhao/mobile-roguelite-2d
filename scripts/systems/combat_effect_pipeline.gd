extends Node
class_name CombatEffectPipeline

signal hit_resolved(target: Node, result: Dictionary)
signal status_applied(target: Node, status_id: String)

const TargetSelectorScript = preload("res://scripts/weapons/target_selector.gd")
const HitResolverScript = preload("res://scripts/systems/hit_resolver.gd")
const MAX_QUEUED_REQUESTS := 32

var target_selector = TargetSelectorScript.new()
var hit_resolver = HitResolverScript.new()
var pool_service: Node
var carrier_parent: Node
var carrier_scenes: Dictionary = {}
var queued_requests: Array[Dictionary] = []
var queued_request_ids: Dictionary = {}
var current_context: Dictionary = {}
var registered_status_ids: Dictionary = {}
var persistent_carriers: Dictionary = {}

func configure(
	new_pool_service: Node,
	new_carrier_parent: Node,
	new_carrier_scenes: Dictionary
) -> void:
	pool_service = new_pool_service
	carrier_parent = new_carrier_parent
	carrier_scenes = new_carrier_scenes.duplicate()

func execute_request(request: Dictionary, context: Dictionary) -> String:
	current_context = context.duplicate(false)
	return _execute_request(request, context, true)

func update_context(context: Dictionary) -> void:
	current_context = context.duplicate(false)
	var targets: Array = context.get("targets", [])
	var service := _get_pool_service(context)
	if service == null:
		return
	for carrier in service.active_by_id.values():
		if is_instance_valid(carrier) and carrier.has_method("update_context"):
			carrier.update_context(targets)

func register_target(target: Node) -> void:
	if target == null:
		return
	var status := target.get_node_or_null("StatusController")
	if status == null or not status.has_signal("status_damage_requested"):
		return
	var status_id := status.get_instance_id()
	if registered_status_ids.has(status_id):
		return
	status.status_damage_requested.connect(_on_status_damage_requested)
	registered_status_ids[status_id] = true

func get_queued_count() -> int:
	return queued_requests.size()

func _physics_process(_delta: float) -> void:
	_process_queue()
	if not current_context.is_empty():
		update_context(current_context)

func _execute_request(
	request: Dictionary,
	context: Dictionary,
	allow_queue: bool
) -> String:
	var carrier_definition_value: Variant = request.get("carrier", {})
	var target_definition_value: Variant = request.get("target", {})
	if (
		typeof(carrier_definition_value) != TYPE_DICTIONARY
		or typeof(target_definition_value) != TYPE_DICTIONARY
	):
		return "invalid_request"
	var carrier_definition: Dictionary = carrier_definition_value
	var carrier_id := String(carrier_definition.get("id", ""))
	if not carrier_scenes.has(carrier_id):
		return "invalid_request"
	var requested_count := maxi(1, int(carrier_definition.get("count", 1)))
	if carrier_id == "orbit" and requested_count > 8:
		return "invalid_request"
	if carrier_id == "summon" and requested_count > 6:
		return "invalid_request"
	var selection_context := context.duplicate(false)
	selection_context["count"] = requested_count
	var selection := target_selector.select(
		target_definition_value,
		context.get("origin", Vector2.ZERO),
		context.get("targets", []),
		selection_context
	)
	if String(selection.get("status", "")) != "selected":
		return "no_target"

	var service := _get_pool_service(context)
	var parent := _get_carrier_parent(context)
	if service == null or parent == null:
		return "invalid_request"
	if carrier_id == "orbit":
		return _execute_orbit(
			service,
			parent,
			request,
			context,
			requested_count,
			allow_queue
		)
	var spawn_count := requested_count if carrier_id in ["projectile", "summon"] else 1
	if not service.can_acquire(carrier_id, spawn_count):
		return _queue_request(request) if allow_queue else "pool_queued"

	match carrier_id:
		"projectile":
			_spawn_projectiles(service, parent, request, selection)
		"area":
			_spawn_area(service, parent, request, selection, context.get("targets", []))
		"summon":
			_spawn_summons(service, parent, request, selection, context)
		_:
			return "invalid_request"
	return "executed"

func _spawn_projectiles(
	service: Node,
	parent: Node,
	request: Dictionary,
	selection: Dictionary
) -> void:
	var directions := _build_projectile_directions(request, selection)
	for direction in directions:
		var carrier = service.acquire("projectile", carrier_scenes["projectile"], parent)
		_connect_carrier(carrier)
		carrier.global_position = selection.get("origin", Vector2.ZERO)
		carrier.configure_from_request(direction, request, current_context.get("owner"))

func _spawn_area(
	service: Node,
	parent: Node,
	request: Dictionary,
	selection: Dictionary,
	targets: Array
) -> void:
	var carrier = service.acquire("area", carrier_scenes["area"], parent)
	_connect_carrier(carrier)
	carrier.configure_from_request(
		selection.get("origin", Vector2.ZERO),
		request,
		current_context.get("owner")
	)
	carrier.update_context(targets)
	carrier.finish_instant()

func _execute_orbit(
	service: Node,
	parent: Node,
	request: Dictionary,
	context: Dictionary,
	requested_count: int,
	allow_queue: bool
) -> String:
	var persistent_key := "%s/%s" % [
		String(request.get("weapon_id", "")),
		String(request.get("effect_id", "")),
	]
	var existing: Array[Node] = []
	for carrier in persistent_carriers.get(persistent_key, []):
		if (
			is_instance_valid(carrier)
			and (
				not carrier.has_method("is_pool_active")
				or bool(carrier.is_pool_active())
			)
		):
			existing.append(carrier)
	var additional := maxi(0, requested_count - existing.size())
	if additional > 0 and not service.can_acquire("orbit", additional):
		return _queue_request(request) if allow_queue else "pool_queued"
	while existing.size() > requested_count:
		var removed: Node = existing.pop_back()
		service.release(removed)
	while existing.size() < requested_count:
		var carrier = service.acquire("orbit", carrier_scenes["orbit"], parent)
		_connect_carrier(carrier)
		existing.append(carrier)
	for index in range(existing.size()):
		existing[index].configure_from_request(
			index,
			existing.size(),
			request,
			context.get("owner")
		)
		existing[index].update_context(context.get("targets", []))
	persistent_carriers[persistent_key] = existing
	return "executed"

func _spawn_summons(
	service: Node,
	parent: Node,
	request: Dictionary,
	selection: Dictionary,
	context: Dictionary
) -> void:
	var carrier_definition: Dictionary = request.get("carrier", {})
	var count := maxi(1, int(carrier_definition.get("count", 1)))
	var origin: Vector2 = selection.get("origin", Vector2.ZERO)
	for index in range(count):
		var carrier = service.acquire("summon", carrier_scenes["summon"], parent)
		_connect_carrier(carrier)
		var offset := Vector2.RIGHT.rotated(TAU * float(index) / float(count)) * 12.0
		carrier.configure_from_request(request, context.get("owner"), origin + offset)
		carrier.update_context(context.get("targets", []))

func _build_projectile_directions(
	request: Dictionary,
	selection: Dictionary
) -> Array[Vector2]:
	var carrier: Dictionary = request.get("carrier", {})
	var count := maxi(1, int(carrier.get("count", 1)))
	var selected_directions: Array = selection.get("directions", [])
	var result: Array[Vector2] = []
	if selected_directions.size() == count:
		for direction in selected_directions:
			result.append(Vector2(direction).normalized())
		return result
	var base_direction := Vector2.RIGHT
	if not selected_directions.is_empty():
		base_direction = Vector2(selected_directions[0]).normalized()
	var spread_degrees := float(carrier.get("spread_degrees", 8.0))
	for index in range(count):
		var offset := deg_to_rad(spread_degrees * (index - (count - 1) / 2.0))
		result.append(base_direction.rotated(offset))
	return result

func _connect_carrier(carrier: Node) -> void:
	if carrier == null:
		return
	var hit_callback := Callable(self, "_on_hit_requested")
	if carrier.has_signal("hit_requested") and not carrier.is_connected("hit_requested", hit_callback):
		carrier.connect("hit_requested", hit_callback)

func _on_hit_requested(target: Node, packet: Dictionary) -> void:
	var result := hit_resolver.resolve(target, packet)
	hit_resolved.emit(target, result)
	for status_id in result.get("applied_statuses", []):
		status_applied.emit(target, String(status_id))

func _on_status_damage_requested(target: Node, packet: Dictionary) -> void:
	var result := hit_resolver.resolve_status_damage(target, packet)
	hit_resolved.emit(target, result)

func _queue_request(request: Dictionary) -> String:
	var request_id := int(request.get("request_id", 0))
	if queued_request_ids.has(request_id):
		return "pool_queued"
	if queued_requests.size() >= MAX_QUEUED_REQUESTS:
		return "invalid_request"
	queued_requests.append(request.duplicate(true))
	queued_request_ids[request_id] = true
	return "pool_queued"

func _process_queue() -> void:
	if queued_requests.is_empty() or current_context.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for request in queued_requests:
		var result := _execute_request(request, current_context, false)
		if result == "pool_queued":
			remaining.append(request)
		else:
			queued_request_ids.erase(int(request.get("request_id", 0)))
	queued_requests = remaining

func _get_pool_service(context: Dictionary) -> Node:
	var service_value: Variant = context.get("pool_service", pool_service)
	return service_value as Node

func _get_carrier_parent(context: Dictionary) -> Node:
	var parent_value: Variant = context.get("parent", carrier_parent)
	return parent_value as Node
