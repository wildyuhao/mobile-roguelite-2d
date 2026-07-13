extends Node
class_name StartingWardVisual

@export var sprite_path: NodePath
@export var rotation_speed: float = 0.55

@onready var ward_sprite: Sprite2D = get_node_or_null(sprite_path)

var pulse_time: float = 0.0
var base_scale: Vector2 = Vector2.ONE
var scale_captured: bool = false

func _ready() -> void:
	_resolve_sprite()

func _process(delta: float) -> void:
	refresh_visual(delta)

func refresh_visual(delta: float) -> void:
	_resolve_sprite()
	if ward_sprite == null:
		return

	var owner_node := get_parent()
	var active := (
		owner_node != null
		and owner_node.has_method("is_starting_ward_active")
		and bool(owner_node.call("is_starting_ward_active"))
	)
	ward_sprite.visible = active
	if not active:
		ward_sprite.scale = base_scale
		return

	pulse_time += maxf(0.0, delta)
	ward_sprite.rotation += rotation_speed * maxf(0.0, delta)
	var ratio := 1.0
	if owner_node.has_method("get_starting_ward_ratio"):
		ratio = float(owner_node.call("get_starting_ward_ratio"))
	var pulse_speed := 14.0 if ratio <= 0.25 else 4.0
	var pulse := sin(pulse_time * pulse_speed)
	ward_sprite.modulate.a = 0.72 + pulse * 0.16
	ward_sprite.scale = base_scale * (1.0 + pulse * 0.025)

func _resolve_sprite() -> void:
	if ward_sprite == null and not sprite_path.is_empty():
		ward_sprite = get_node_or_null(sprite_path)
	if ward_sprite != null and not scale_captured:
		base_scale = ward_sprite.scale
		scale_captured = true
