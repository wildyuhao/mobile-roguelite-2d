extends RefCounted
class_name TargetSelector

func select(
	target_definition: Dictionary,
	origin: Vector2,
	candidates: Array,
	context: Dictionary = {}
) -> Dictionary:
	var mode := String(target_definition.get("id", ""))
	match mode:
		"self":
			return _selection(origin, [], [])
		"radial":
			return _select_radial(origin, context)
		"nearest":
			return _select_nearest(origin, candidates, float(target_definition.get("range", 0.0)))
		"lowest_health":
			return _select_lowest_health(origin, candidates, float(target_definition.get("range", 0.0)))
		"sector":
			return _select_sector(target_definition, origin, candidates, context)
	return _no_target(origin)

func _select_nearest(origin: Vector2, candidates: Array, max_range: float) -> Dictionary:
	var closest: Node2D = null
	var closest_distance := INF
	for candidate in candidates:
		if not _is_valid_candidate(candidate):
			continue
		var node := candidate as Node2D
		var distance := origin.distance_to(node.global_position)
		if distance <= max_range and distance < closest_distance:
			closest = node
			closest_distance = distance
	if closest == null:
		return _no_target(origin)
	return _selection(
		origin,
		[closest],
		[_safe_direction(origin, closest.global_position)]
	)

func _select_lowest_health(
	origin: Vector2,
	candidates: Array,
	max_range: float
) -> Dictionary:
	var selected: Node2D = null
	var selected_ratio := INF
	var selected_distance := INF
	for candidate in candidates:
		if not _is_valid_candidate(candidate):
			continue
		var node := candidate as Node2D
		var distance := origin.distance_to(node.global_position)
		if distance > max_range:
			continue
		var ratio := _health_ratio(node)
		if ratio < selected_ratio or (is_equal_approx(ratio, selected_ratio) and distance < selected_distance):
			selected = node
			selected_ratio = ratio
			selected_distance = distance
	if selected == null:
		return _no_target(origin)
	return _selection(
		origin,
		[selected],
		[_safe_direction(origin, selected.global_position)]
	)

func _select_sector(
	target_definition: Dictionary,
	origin: Vector2,
	candidates: Array,
	context: Dictionary
) -> Dictionary:
	var max_range := float(target_definition.get("range", 0.0))
	var half_angle := deg_to_rad(float(target_definition.get("angle_degrees", 60.0)) * 0.5)
	var aim_direction: Vector2 = context.get("aim_direction", Vector2.ZERO)
	if aim_direction == Vector2.ZERO:
		var nearest := _select_nearest(origin, candidates, max_range)
		var nearest_directions: Array = nearest.get("directions", [])
		if not nearest_directions.is_empty():
			aim_direction = nearest_directions[0]
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	aim_direction = aim_direction.normalized()

	var targets: Array[Node2D] = []
	for candidate in candidates:
		if not _is_valid_candidate(candidate):
			continue
		var node := candidate as Node2D
		var offset := node.global_position - origin
		if offset.length() > max_range or offset == Vector2.ZERO:
			continue
		if absf(aim_direction.angle_to(offset.normalized())) <= half_angle:
			targets.append(node)
	if targets.is_empty():
		return _no_target(origin)
	return _selection(origin, targets, [aim_direction])

func _select_radial(origin: Vector2, context: Dictionary) -> Dictionary:
	var count := maxi(1, int(context.get("count", 1)))
	var start_angle := float(context.get("run_time", 0.0)) * 0.8
	var directions: Array[Vector2] = []
	var angle_step := TAU / float(count)
	for index in range(count):
		directions.append(Vector2.RIGHT.rotated(start_angle + angle_step * index))
	return _selection(origin, [], directions)

func _health_ratio(node: Node) -> float:
	var health := node.get_node_or_null("HealthComponent")
	if health == null:
		return 1.0
	var maximum := maxi(1, int(health.get("max_health")))
	return float(health.get("current_health")) / float(maximum)

func _is_valid_candidate(candidate: Variant) -> bool:
	if not candidate is Node2D or not is_instance_valid(candidate):
		return false
	var node := candidate as Node2D
	if node.has_method("is_pool_active") and not bool(node.call("is_pool_active")):
		return false
	var health := node.get_node_or_null("HealthComponent")
	if health != null and health.has_method("is_dead") and bool(health.call("is_dead")):
		return false
	return true

func _safe_direction(origin: Vector2, destination: Vector2) -> Vector2:
	var direction := origin.direction_to(destination)
	return Vector2.RIGHT if direction == Vector2.ZERO else direction

func _selection(
	origin: Vector2,
	targets_value: Array,
	directions_value: Array
) -> Dictionary:
	return {
		"status": "selected",
		"origin": origin,
		"targets": targets_value,
		"directions": directions_value,
	}

func _no_target(origin: Vector2) -> Dictionary:
	return {
		"status": "no_target",
		"origin": origin,
		"targets": [],
		"directions": [],
	}
