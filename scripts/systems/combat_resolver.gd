extends RefCounted
class_name CombatResolver

func find_closest_enemy(origin: Vector2, enemies: Array, max_range: float) -> Node2D:
	var closest: Node2D = null
	var closest_distance: float = INF
	for enemy in enemies:
		if not enemy is Node2D:
			continue
		var distance: float = origin.distance_to(enemy.global_position)
		if distance <= max_range and distance < closest_distance:
			closest = enemy
			closest_distance = distance
	return closest

func get_enemies_in_radius(origin: Vector2, enemies: Array, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for enemy in enemies:
		if enemy is Node2D and origin.distance_to(enemy.global_position) <= radius:
			result.append(enemy)
	return result

func build_spread_directions(base_direction: Vector2, count: int, spread_degrees: float) -> Array[Vector2]:
	var safe_count: int = max(1, count)
	var direction: Vector2 = base_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var result: Array[Vector2] = []
	for index in range(safe_count):
		var spread: float = deg_to_rad(spread_degrees * (index - (safe_count - 1) / 2.0))
		result.append(direction.rotated(spread))
	return result
