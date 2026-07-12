extends Area2D
class_name ExperiencePickup

signal collected(amount: int)
signal release_requested(node: Node)

const GameConstantsScript = preload("res://scripts/core/constants.gd")

@export var experience_value: int = 1

var _collected := false
var collection_shape: CollisionShape2D
var base_collection_radius: float = 10.0
var base_collection_radius_captured := false
var collection_shape_is_unique := false
var pool_active: bool = true

func configure(new_experience_value: int) -> void:
	experience_value = max(1, new_experience_value)

func _ready() -> void:
	add_to_group(GameConstantsScript.PICKUP_GROUP)
	_resolve_collection_shape()
	body_entered.connect(_on_body_entered)

func set_collection_radius_bonus(bonus: float) -> void:
	_resolve_collection_shape()
	if collection_shape == null or not collection_shape.shape is CircleShape2D:
		return

	var circle := collection_shape.shape as CircleShape2D
	circle.radius = max(1.0, base_collection_radius + max(0.0, bonus))

func collect() -> void:
	if _collected:
		return

	_collected = true
	collected.emit(experience_value)
	_release_or_free()

func _on_body_entered(body: Node) -> void:
	if body != null and body.is_in_group(GameConstantsScript.PLAYER_GROUP):
		collect()

func _resolve_collection_shape() -> void:
	if collection_shape == null:
		collection_shape = get_node_or_null("CollisionShape2D")
	if collection_shape == null or not collection_shape.shape is CircleShape2D:
		return
	if not collection_shape_is_unique:
		collection_shape.shape = collection_shape.shape.duplicate()
		collection_shape_is_unique = true
	if not base_collection_radius_captured:
		base_collection_radius = (collection_shape.shape as CircleShape2D).radius
		base_collection_radius_captured = true

func activate_from_pool() -> void:
	pool_active = true
	_collected = false
	experience_value = 1
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if not is_in_group(GameConstantsScript.PICKUP_GROUP):
		add_to_group(GameConstantsScript.PICKUP_GROUP)
	_resolve_collection_shape()
	set_collection_radius_bonus(0.0)
	if collection_shape != null:
		collection_shape.set_deferred("disabled", false)

func deactivate_for_pool() -> void:
	pool_active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group(GameConstantsScript.PICKUP_GROUP)
	if collection_shape != null:
		collection_shape.set_deferred("disabled", true)

func _release_or_free() -> void:
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)
