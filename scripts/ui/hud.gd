extends CanvasLayer
class_name HUD

const UPGRADE_FEEDBACK_DURATION := 1.4

@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel
@onready var experience_label: Label = $MarginContainer/VBoxContainer/ExperienceLabel
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var upgrade_feedback_label: Label = $MarginContainer/VBoxContainer/UpgradeFeedbackLabel

var upgrade_feedback_time_remaining: float = 0.0

func _process(delta: float) -> void:
	if upgrade_feedback_time_remaining <= 0.0:
		return
	upgrade_feedback_time_remaining -= delta
	if upgrade_feedback_time_remaining <= 0.0 and upgrade_feedback_label != null:
		upgrade_feedback_label.hide()

func set_run_time(seconds: float) -> void:
	var minutes := int(seconds / 60.0)
	var remainder := int(seconds) % 60
	timer_label.text = "%02d:%02d" % [minutes, remainder]

func set_level(level: int) -> void:
	level_label.text = "Lv %d" % level

func set_experience(current: int, required: int) -> void:
	experience_label.text = "EXP %d/%d" % [current, required]

func set_health(current: int, maximum: int) -> void:
	if health_label == null:
		health_label = get_node_or_null("MarginContainer/VBoxContainer/HealthLabel")
	if health_label != null:
		health_label.text = "HP %d/%d" % [max(0, current), max(1, maximum)]

func show_upgrade_feedback(display_name: String) -> void:
	if upgrade_feedback_label == null:
		upgrade_feedback_label = get_node_or_null("MarginContainer/VBoxContainer/UpgradeFeedbackLabel")
	if upgrade_feedback_label == null:
		return
	upgrade_feedback_label.text = "已选择：%s" % display_name
	upgrade_feedback_label.show()
	upgrade_feedback_time_remaining = UPGRADE_FEEDBACK_DURATION
