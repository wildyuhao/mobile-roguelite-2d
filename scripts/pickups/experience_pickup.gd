extends Area2D
class_name ExperiencePickup

signal collected(amount: int)

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var experience_value: int = 1

var _collected := false

func configure(new_experience_value: int) -> void:
	experience_value = max(1, new_experience_value)

func _ready() -> void:
	add_to_group(GameConstantsScript.PICKUP_GROUP)
	body_entered.connect(_on_body_entered)

func collect() -> void:
	if _collected:
		return

	_collected = true
	collected.emit(experience_value)
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(GameConstantsScript.PLAYER_GROUP):
		collect()
