extends RefCounted
class_name FormationPlanner

func build_slots(
	definition: Dictionary,
	count: int,
	radius: float,
	seed_angle: float
) -> Array[Vector2]:
	if count <= 0:
		return []
	var scaled_radius := radius * float(definition.get("radius_scale", 1.0))
	match String(definition.get("pattern", "ring_gap")):
		"wedge":
			return _wedge(
				count,
				scaled_radius,
				seed_angle,
				float(definition.get("row_spacing", 62.0)),
				float(definition.get("column_spacing", 58.0))
			)
		"escort":
			return _escort(
				count,
				scaled_radius,
				seed_angle,
				float(definition.get("front_ratio", 0.72)),
				float(definition.get("rear_offset", 92.0))
			)
		"leader_flanks":
			return _leader_flanks(
				count,
				scaled_radius,
				seed_angle,
				deg_to_rad(float(definition.get("flank_angle_degrees", 36.0))),
				float(definition.get("depth_spacing", 64.0))
			)
		"dual_ring":
			return _dual_ring(
				count,
				scaled_radius,
				seed_angle,
				float(definition.get("inner_radius_scale", 0.72))
			)
		"pincer":
			return _pincer(
				count,
				scaled_radius,
				seed_angle,
				deg_to_rad(float(definition.get("side_angle_degrees", 76.0))),
				float(definition.get("depth_spacing", 54.0))
			)
		"corridor":
			return _corridor(
				count,
				scaled_radius,
				seed_angle,
				float(definition.get("lane_spacing", 68.0)),
				float(definition.get("depth_spacing", 58.0))
			)
		_:
			return _ring_gap(
				count,
				scaled_radius,
				seed_angle,
				deg_to_rad(float(definition.get("gap_degrees", 70.0)))
			)

func _ring_gap(
	count: int,
	radius: float,
	angle: float,
	gap: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var usable := TAU - gap
	for index in range(count):
		var phase := (float(index) + 0.5) / float(count)
		result.append(
			Vector2.RIGHT.rotated(angle + gap * 0.5 + usable * phase) * radius
		)
	return result

func _wedge(
	count: int,
	radius: float,
	angle: float,
	row_spacing: float,
	column_spacing: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	for index in range(count):
		var row := int(floor((sqrt(8.0 * index + 1.0) - 1.0) * 0.5))
		var row_start := row * (row + 1) / 2
		var column := index - row_start
		result.append(
			forward * (radius + row * row_spacing)
			+ side * (float(column) - float(row) * 0.5) * column_spacing
		)
	return result

func _escort(
	count: int,
	radius: float,
	angle: float,
	front_ratio: float,
	rear_offset: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var front_count := clampi(int(ceil(count * front_ratio)), 1, count)
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	for index in range(count):
		var rear := index >= front_count
		var local_index := index - front_count if rear else index
		var local_count := count - front_count if rear else front_count
		var offset := (
			float(local_index) - float(maxi(1, local_count) - 1) * 0.5
		) * 58.0
		result.append(
			forward * (radius + (rear_offset if rear else 0.0))
			+ side * offset
		)
	return result

func _leader_flanks(
	count: int,
	radius: float,
	angle: float,
	flank_angle: float,
	depth: float
) -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2.RIGHT.rotated(angle) * radius]
	for index in range(1, count):
		var side_sign := -1.0 if index % 2 == 0 else 1.0
		var rank := float((index + 1) / 2)
		result.append(
			Vector2.RIGHT.rotated(angle + flank_angle * side_sign)
			* (radius + rank * depth)
		)
	return result

func _dual_ring(
	count: int,
	radius: float,
	angle: float,
	inner_scale: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(count):
		var ring_radius := radius * (inner_scale if index % 2 == 0 else 1.0)
		result.append(
			Vector2.RIGHT.rotated(angle + TAU * float(index) / float(count))
			* ring_radius
		)
	return result

func _pincer(
	count: int,
	radius: float,
	angle: float,
	side_angle: float,
	depth: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for index in range(count):
		var side_sign := -1.0 if index % 2 == 0 else 1.0
		var rank := float(index / 2)
		result.append(
			Vector2.RIGHT.rotated(angle + side_angle * side_sign)
			* (radius + rank * depth)
		)
	return result

func _corridor(
	count: int,
	radius: float,
	angle: float,
	lane_spacing: float,
	depth: float
) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var forward := Vector2.RIGHT.rotated(angle)
	var side := forward.orthogonal()
	for index in range(count):
		var lane := index % 3 - 1
		var rank := index / 3
		result.append(
			forward * (radius + rank * depth)
			+ side * lane * lane_spacing
		)
	return result
