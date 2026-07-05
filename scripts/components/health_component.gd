extends Node
class_name HealthComponent

signal died
signal damaged(amount: int)
signal healed(amount: int)

var max_health: int = 1
var current_health: int = 1

func configure(new_max_health: int) -> void:
	max_health = max(1, new_max_health)
	current_health = max_health

func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return

	current_health = max(0, current_health - amount)
	damaged.emit(amount)
	if current_health == 0:
		died.emit()

func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return

	var before := current_health
	current_health = min(max_health, current_health + amount)
	healed.emit(current_health - before)

func is_dead() -> bool:
	return current_health <= 0
