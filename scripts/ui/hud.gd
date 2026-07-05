extends CanvasLayer
class_name HUD

@onready var timer_label: Label = $MarginContainer/VBoxContainer/TimerLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/LevelLabel
@onready var experience_label: Label = $MarginContainer/VBoxContainer/ExperienceLabel
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel

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
