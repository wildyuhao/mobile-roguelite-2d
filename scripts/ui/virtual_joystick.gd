extends Control
class_name MobileVirtualJoystick

signal move_vector_changed(move_vector: Vector2)

@export var base_color := Color(0.06, 0.07, 0.08, 0.42)
@export var base_ring_color := Color(0.72, 0.88, 0.95, 0.38)
@export var knob_color := Color(0.75, 0.95, 1.0, 0.62)

var move_vector: Vector2 = Vector2.ZERO
var is_active: bool = false
var active_touch_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(196, 196)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag and (active_touch_index == -1 or event.index == active_touch_index):
		update_drag_local(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_drag_local(event.position)
		else:
			end_drag()
	elif event is InputEventMouseMotion and is_active:
		update_drag_local(event.position)

func begin_drag_local(local_position: Vector2) -> bool:
	if local_position.distance_to(_get_center()) > _get_radius():
		return false

	is_active = true
	update_drag_local(local_position)
	return true

func update_drag_local(local_position: Vector2) -> void:
	if not is_active:
		return

	var radius := _get_radius()
	var raw_vector := (local_position - _get_center()) / radius
	if raw_vector.length() > 1.0:
		raw_vector = raw_vector.normalized()
	_set_move_vector(raw_vector)

func end_drag() -> void:
	is_active = false
	active_touch_index = -1
	_set_move_vector(Vector2.ZERO)

func _draw() -> void:
	var center := _get_center()
	var radius := _get_radius()
	draw_circle(center, radius, base_color)
	draw_arc(center, radius, 0.0, TAU, 48, base_ring_color, 3.0)
	draw_circle(center + move_vector * radius, radius * 0.34, knob_color)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if begin_drag_local(event.position):
			active_touch_index = event.index
	elif event.index == active_touch_index:
		end_drag()

func _set_move_vector(new_vector: Vector2) -> void:
	if new_vector.length() > 1.0:
		new_vector = new_vector.normalized()
	if move_vector == new_vector:
		return

	move_vector = new_vector
	move_vector_changed.emit(move_vector)
	queue_redraw()

func _get_center() -> Vector2:
	return size * 0.5

func _get_radius() -> float:
	return max(1.0, min(size.x, size.y) * 0.42)
