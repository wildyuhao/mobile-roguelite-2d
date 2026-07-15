extends Node
class_name DirectionalAnimation

@export var sprite_path: NodePath = NodePath("../AnimatedSprite2D")
@export var front_strip: Texture2D
@export var back_strip: Texture2D
@export var side_strip: Texture2D
@export var idle_front_strip: Texture2D
@export var frame_size := Vector2i(128, 128)
@export var frame_count: int = 6
@export var animation_fps: float = 10.0
@export var idle_frame_index: int = 1
@export var idle_frame_count: int = 16
@export var idle_animation_fps: float = 3.2
@export var direction_switch_hysteresis: float = 0.12

var sprite: AnimatedSprite2D
var last_direction: String = "front"
var last_side_sign: float = 1.0

func _ready() -> void:
	if sprite == null:
		sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	configure(sprite, front_strip, back_strip, side_strip, idle_front_strip)

func configure(
	target_sprite: AnimatedSprite2D,
	front: Texture2D,
	back: Texture2D,
	side: Texture2D,
	idle_front: Texture2D = null
) -> bool:
	if target_sprite == null or front == null or back == null or side == null:
		return false

	sprite = target_sprite
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_direction(frames, "front", front, idle_front)
	_add_direction(frames, "back", back)
	_add_direction(frames, "side", side)
	sprite.sprite_frames = frames
	sprite.play(&"idle_front")
	return true

func update_motion(motion: Vector2) -> StringName:
	if sprite == null:
		return StringName()

	var moving := motion.length() > 0.05
	if moving:
		last_direction = _resolve_direction(motion)
		if last_direction == "side":
			last_side_sign = signf(motion.x)
	sprite.flip_h = last_direction == "side" and last_side_sign < 0.0

	var prefix := "walk" if moving else "idle"
	var animation := StringName("%s_%s" % [prefix, last_direction])
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
	return animation

func _resolve_direction(motion: Vector2) -> String:
	var horizontal := absf(motion.x)
	var vertical := absf(motion.y)
	var hysteresis := maxf(0.0, direction_switch_hysteresis)
	if last_direction == "side":
		if vertical <= horizontal + hysteresis:
			return "side"
	elif horizontal > vertical + hysteresis:
		return "side"
	return "back" if motion.y < 0.0 else "front"

func _add_direction(
	frames: SpriteFrames,
	direction: String,
	texture: Texture2D,
	idle_texture: Texture2D = null
) -> void:
	var idle_name := StringName("idle_%s" % direction)
	var walk_name := StringName("walk_%s" % direction)
	frames.add_animation(idle_name)
	frames.set_animation_loop(idle_name, true)
	frames.set_animation_speed(idle_name, maxf(0.1, idle_animation_fps))
	if idle_texture != null:
		for index in range(maxi(1, idle_frame_count)):
			frames.add_frame(idle_name, _atlas_frame(idle_texture, index))
	else:
		var neutral_frame := clampi(idle_frame_index, 0, maxi(0, frame_count - 1))
		frames.add_frame(idle_name, _atlas_frame(texture, neutral_frame))
	frames.add_animation(walk_name)
	frames.set_animation_loop(walk_name, true)
	frames.set_animation_speed(walk_name, animation_fps)
	for index in range(frame_count):
		frames.add_frame(walk_name, _atlas_frame(texture, index))

func _atlas_frame(texture: Texture2D, index: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
	return frame
