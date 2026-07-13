extends CanvasLayer
class_name HUD

const UPGRADE_FEEDBACK_DURATION := 1.4
const DAMAGE_FEEDBACK_DURATION := 0.18
const DAMAGE_FEEDBACK_COLOR := Color(1.0, 0.28, 0.28, 1.0)
const DAMAGE_FEEDBACK_PUNCH := 0.16
const DAMAGE_BAR_PUNCH := 0.05

@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopRow/TimerLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/TopRow/LevelLabel
@onready var experience_bar: ProgressBar = $MarginContainer/VBoxContainer/ExperienceBar
@onready var experience_label: Label = $MarginContainer/VBoxContainer/ExperienceBar/ExperienceLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var upgrade_feedback_label: Label = $MarginContainer/VBoxContainer/UpgradeFeedbackLabel

var upgrade_feedback_time_remaining: float = 0.0
var damage_feedback_time_remaining: float = 0.0
var health_label_base_scale := Vector2.ONE
var health_label_base_modulate := Color.WHITE
var health_bar_base_scale := Vector2.ONE
var health_bar_base_modulate := Color.WHITE

func _ready() -> void:
	_resolve_nodes()
	if health_label != null:
		health_label_base_scale = health_label.scale
		health_label_base_modulate = health_label.modulate
		health_label.pivot_offset = health_label.size * 0.5
	if health_bar != null:
		health_bar_base_scale = health_bar.scale
		health_bar_base_modulate = health_bar.modulate
		health_bar.pivot_offset = health_bar.size * 0.5

func _process(delta: float) -> void:
	_tick_upgrade_feedback(delta)
	_tick_damage_feedback(delta)

func set_run_time(seconds: float) -> void:
	_resolve_nodes()
	var minutes := int(seconds / 60.0)
	var remainder := int(seconds) % 60
	timer_label.text = "%02d:%02d" % [minutes, remainder]

func set_level(level: int) -> void:
	_resolve_nodes()
	level_label.text = "等级 %d" % level

func set_experience(current: int, required: int) -> void:
	_resolve_nodes()
	var maximum: int = maxi(1, required)
	var safe_current: int = clampi(current, 0, maximum)
	experience_bar.max_value = maximum
	experience_bar.value = safe_current
	experience_label.text = "灵气 %d / %d" % [safe_current, maximum]

func set_health(current: int, maximum: int) -> void:
	_resolve_nodes()
	var safe_maximum: int = maxi(1, maximum)
	var safe_current: int = clampi(current, 0, safe_maximum)
	health_bar.max_value = safe_maximum
	health_bar.value = safe_current
	health_label.text = "生命 %d / %d" % [safe_current, safe_maximum]

func show_upgrade_feedback(display_name: String) -> void:
	if upgrade_feedback_label == null:
		upgrade_feedback_label = get_node_or_null("MarginContainer/VBoxContainer/UpgradeFeedbackLabel")
	if upgrade_feedback_label == null:
		return
	upgrade_feedback_label.text = "已选择：%s" % display_name
	upgrade_feedback_label.show()
	upgrade_feedback_time_remaining = UPGRADE_FEEDBACK_DURATION

func show_damage_feedback(_amount: int) -> void:
	_resolve_nodes()
	if health_label == null or health_bar == null:
		return
	health_label.scale = health_label_base_scale * (1.0 + DAMAGE_FEEDBACK_PUNCH)
	health_label.modulate = DAMAGE_FEEDBACK_COLOR
	health_bar.scale = health_bar_base_scale * (1.0 + DAMAGE_BAR_PUNCH)
	health_bar.modulate = DAMAGE_FEEDBACK_COLOR
	damage_feedback_time_remaining = DAMAGE_FEEDBACK_DURATION

func _tick_upgrade_feedback(delta: float) -> void:
	if upgrade_feedback_time_remaining <= 0.0:
		return
	upgrade_feedback_time_remaining = maxf(
		0.0,
		upgrade_feedback_time_remaining - maxf(0.0, delta)
	)
	if upgrade_feedback_time_remaining <= 0.0 and upgrade_feedback_label != null:
		upgrade_feedback_label.hide()

func _tick_damage_feedback(delta: float) -> void:
	if damage_feedback_time_remaining <= 0.0 or health_label == null or health_bar == null:
		return
	damage_feedback_time_remaining = maxf(
		0.0,
		damage_feedback_time_remaining - maxf(0.0, delta)
	)
	if damage_feedback_time_remaining <= 0.0:
		health_label.scale = health_label_base_scale
		health_label.modulate = health_label_base_modulate
		health_bar.scale = health_bar_base_scale
		health_bar.modulate = health_bar_base_modulate
		return
	var ratio := damage_feedback_time_remaining / DAMAGE_FEEDBACK_DURATION
	health_label.scale = health_label_base_scale * (
		1.0 + DAMAGE_FEEDBACK_PUNCH * ratio
	)
	health_label.modulate = health_label_base_modulate.lerp(
		DAMAGE_FEEDBACK_COLOR,
		ratio
	)
	health_bar.scale = health_bar_base_scale * (1.0 + DAMAGE_BAR_PUNCH * ratio)
	health_bar.modulate = health_bar_base_modulate.lerp(DAMAGE_FEEDBACK_COLOR, ratio)

func _resolve_nodes() -> void:
	if timer_label == null:
		timer_label = get_node_or_null("MarginContainer/VBoxContainer/TopRow/TimerLabel")
	if level_label == null:
		level_label = get_node_or_null("MarginContainer/VBoxContainer/TopRow/LevelLabel")
	if experience_bar == null:
		experience_bar = get_node_or_null("MarginContainer/VBoxContainer/ExperienceBar")
	if experience_label == null:
		experience_label = get_node_or_null("MarginContainer/VBoxContainer/ExperienceBar/ExperienceLabel")
	if health_bar == null:
		health_bar = get_node_or_null("MarginContainer/VBoxContainer/HealthBar")
	if health_label == null:
		health_label = get_node_or_null("MarginContainer/VBoxContainer/HealthBar/HealthLabel")
	if upgrade_feedback_label == null:
		upgrade_feedback_label = get_node_or_null("MarginContainer/VBoxContainer/UpgradeFeedbackLabel")
