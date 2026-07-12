extends Node
class_name HitFeedback

const PLAYER_FLASH_DURATION := 0.12
const PLAYER_SPARK_DURATION := 0.18
const PLAYER_LABEL_DURATION := 0.45
const ENEMY_FLASH_DURATION := 0.08
const ENEMY_SPARK_DURATION := 0.12
const PLAYER_COLOR := Color(1.0, 0.24, 0.24, 1.0)
const ENEMY_COLOR := Color(0.55, 1.0, 1.0, 1.0)

@export var target_path: NodePath
@export var spark_path: NodePath
@export var damage_label_path: NodePath

var target_visual: CanvasItem
var target_node: Node2D
var spark_visual: Sprite2D
var damage_label: Label
var base_target_scale := Vector2.ONE
var base_target_modulate := Color.WHITE
var base_spark_scale := Vector2.ONE
var base_label_position := Vector2.ZERO
var base_label_modulate := Color.WHITE
var baseline_valid := false
var active_profile: StringName
var flash_duration := 0.0
var spark_duration := 0.0
var label_duration := 0.0
var flash_remaining := 0.0
var spark_remaining := 0.0
var label_remaining := 0.0
var playing := false

func _ready() -> void:
	_resolve_nodes()
	_capture_baseline()
	reset_feedback()

func configure(
	new_target: CanvasItem,
	new_spark: Sprite2D,
	new_damage_label: Label = null
) -> bool:
	target_visual = new_target
	target_node = new_target as Node2D
	spark_visual = new_spark
	damage_label = new_damage_label
	_capture_baseline()
	reset_feedback()
	return target_visual != null and target_node != null and spark_visual != null

func play_hit(amount: int, profile: StringName) -> bool:
	if profile != &"player" and profile != &"enemy":
		return false
	_resolve_nodes()
	if target_visual == null or target_node == null or spark_visual == null:
		return false
	if playing:
		_restore_visuals()
	_capture_baseline()
	active_profile = profile
	flash_duration = (
		PLAYER_FLASH_DURATION if profile == &"player" else ENEMY_FLASH_DURATION
	)
	spark_duration = (
		PLAYER_SPARK_DURATION if profile == &"player" else ENEMY_SPARK_DURATION
	)
	label_duration = (
		PLAYER_LABEL_DURATION
		if profile == &"player" and damage_label != null
		else 0.0
	)
	flash_remaining = flash_duration
	spark_remaining = spark_duration
	label_remaining = label_duration
	playing = true
	target_visual.self_modulate = (
		PLAYER_COLOR if profile == &"player" else ENEMY_COLOR
	)
	var punch := 0.06 if profile == &"player" else 0.05
	target_node.scale = base_target_scale * (1.0 + punch)
	spark_visual.visible = true
	spark_visual.self_modulate = Color.WHITE
	spark_visual.scale = base_spark_scale * 0.72
	if damage_label != null:
		damage_label.visible = label_duration > 0.0
		damage_label.text = "-%d" % maxi(0, amount)
		damage_label.position = base_label_position
		damage_label.self_modulate = base_label_modulate
	set_process(true)
	return true

func _process(delta: float) -> void:
	if not playing:
		return
	var safe_delta := maxf(0.0, delta)
	flash_remaining = maxf(0.0, flash_remaining - safe_delta)
	spark_remaining = maxf(0.0, spark_remaining - safe_delta)
	label_remaining = maxf(0.0, label_remaining - safe_delta)

	if flash_duration > 0.0:
		var flash_ratio := flash_remaining / flash_duration
		var hit_color := (
			PLAYER_COLOR if active_profile == &"player" else ENEMY_COLOR
		)
		target_visual.self_modulate = base_target_modulate.lerp(
			hit_color,
			flash_ratio
		)
		var punch := 0.06 if active_profile == &"player" else 0.05
		target_node.scale = base_target_scale * (1.0 + punch * flash_ratio)
	if spark_visual != null and spark_duration > 0.0:
		var spark_ratio := spark_remaining / spark_duration
		var spark_progress := 1.0 - spark_ratio
		spark_visual.scale = base_spark_scale * (0.72 + 0.40 * spark_progress)
		spark_visual.self_modulate = Color(1.0, 1.0, 1.0, spark_ratio)
		spark_visual.visible = spark_remaining > 0.0
	if damage_label != null and label_duration > 0.0:
		var label_ratio := label_remaining / label_duration
		var label_progress := 1.0 - label_ratio
		damage_label.position = (
			base_label_position + Vector2(0.0, -24.0 * label_progress)
		)
		damage_label.self_modulate = Color(
			base_label_modulate.r,
			base_label_modulate.g,
			base_label_modulate.b,
			base_label_modulate.a * label_ratio
		)
		damage_label.visible = label_remaining > 0.0

	if (
		flash_remaining <= 0.0
		and spark_remaining <= 0.0
		and label_remaining <= 0.0
	):
		reset_feedback()

func reset_feedback() -> void:
	_restore_visuals()
	flash_remaining = 0.0
	spark_remaining = 0.0
	label_remaining = 0.0
	playing = false
	set_process(false)

func is_playing() -> bool:
	return playing

func _resolve_nodes() -> void:
	if target_visual == null and target_path != NodePath():
		target_visual = get_node_or_null(target_path) as CanvasItem
		target_node = target_visual as Node2D
	if spark_visual == null and spark_path != NodePath():
		spark_visual = get_node_or_null(spark_path) as Sprite2D
	if damage_label == null and damage_label_path != NodePath():
		damage_label = get_node_or_null(damage_label_path) as Label

func _capture_baseline() -> void:
	if target_visual == null or target_node == null or spark_visual == null:
		baseline_valid = false
		return
	base_target_scale = target_node.scale
	base_target_modulate = target_visual.self_modulate
	base_spark_scale = spark_visual.scale
	if damage_label != null:
		base_label_position = damage_label.position
		base_label_modulate = damage_label.self_modulate
	baseline_valid = true

func _restore_visuals() -> void:
	if baseline_valid and target_visual != null and target_node != null:
		target_visual.self_modulate = base_target_modulate
		target_node.scale = base_target_scale
	if spark_visual != null:
		spark_visual.visible = false
		spark_visual.scale = base_spark_scale
		spark_visual.self_modulate = Color.WHITE
	if damage_label != null:
		damage_label.visible = false
		damage_label.position = base_label_position
		damage_label.self_modulate = base_label_modulate
