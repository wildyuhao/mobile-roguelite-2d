extends Node2D
class_name StatusVisual

const PRIORITY := ["freeze", "seal", "armor_break", "burn"]

@export var freeze_texture: Texture2D
@export var seal_texture: Texture2D
@export var armor_break_texture: Texture2D
@export var burn_texture: Texture2D

@onready var icon: Sprite2D = $Icon
@onready var stack_label: Label = $StackLabel

func _ready() -> void:
	reset_visual()

func apply_snapshot(snapshot: Dictionary) -> void:
	_resolve_nodes()
	if icon == null or stack_label == null:
		visible = false
		return
	var selected := ""
	for status_id in PRIORITY:
		if snapshot.has(status_id):
			selected = status_id
			break
	visible = selected != ""
	if not visible:
		stack_label.text = ""
		return
	icon.texture = _texture_for(selected)
	var stacks := int(Dictionary(snapshot[selected]).get("stacks", 1))
	stack_label.text = str(stacks) if stacks > 1 else ""

func reset_visual() -> void:
	apply_snapshot({})

func _resolve_nodes() -> void:
	if icon == null:
		icon = get_node_or_null("Icon") as Sprite2D
	if stack_label == null:
		stack_label = get_node_or_null("StackLabel") as Label

func _texture_for(status_id: String) -> Texture2D:
	match status_id:
		"freeze":
			return freeze_texture
		"seal":
			return seal_texture
		"armor_break":
			return armor_break_texture
		"burn":
			return burn_texture
	return null
