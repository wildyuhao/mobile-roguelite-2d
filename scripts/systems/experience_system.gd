extends Node
class_name ExperienceSystem

signal level_up(new_level: int)
signal experience_changed(current: int, required: int)

var level: int = 1
var current_experience: int = 0

func get_required_experience() -> int:
	return 5 + (level - 1) * 3

func add_experience(amount: int) -> void:
	current_experience += max(0, amount)
	while current_experience >= get_required_experience():
		current_experience -= get_required_experience()
		level += 1
		level_up.emit(level)
	experience_changed.emit(current_experience, get_required_experience())
