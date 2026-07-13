extends CanvasLayer
class_name UpgradeChoicePanel

signal upgrade_selected(upgrade: Dictionary)

@onready var buttons: Array[Button] = [
	$PanelContainer/VBoxContainer/Button1,
	$PanelContainer/VBoxContainer/Button2,
	$PanelContainer/VBoxContainer/Button3,
]

var current_choices: Array[Dictionary] = []
var icon_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_buttons()
	for index in range(buttons.size()):
		buttons[index].pressed.connect(_on_button_pressed.bind(index))
	hide()

func show_choices(choices: Array[Dictionary]) -> void:
	_resolve_buttons()
	current_choices = choices
	for index in range(buttons.size()):
		var button := buttons[index]
		if index < choices.size():
			button.text = _format_choice_text(choices[index])
			button.icon = _load_choice_icon(choices[index])
			button.disabled = false
		else:
			button.text = "无可用强化"
			button.icon = null
			button.disabled = true
	show()

func _on_button_pressed(index: int) -> void:
	_resolve_buttons()
	if index >= current_choices.size():
		return

	var selected := current_choices[index]
	hide()
	upgrade_selected.emit(selected)

func _format_choice_text(choice: Dictionary) -> String:
	var label := String(choice.get("display_name", choice.get("id", "强化")))
	var category := String(choice.get("category_label", ""))
	var progress := String(choice.get("progress_label", ""))
	var header := category
	if category != "" and progress != "":
		header = "%s · %s" % [category, progress]
	elif progress != "":
		header = progress

	var result := label if header == "" else "%s\n%s" % [header, label]
	var summary := String(choice.get("effect_summary", ""))
	if summary != "":
		result += "\n%s" % summary
	return result

func _load_choice_icon(choice: Dictionary) -> Texture2D:
	var icon_path := String(choice.get("icon_path", ""))
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null
	if icon_cache.has(icon_path):
		return icon_cache[icon_path]
	var texture = load(icon_path)
	if texture is Texture2D:
		icon_cache[icon_path] = texture
		return texture
	return null

func _resolve_buttons() -> void:
	if buttons.size() == 3 and buttons[0] != null and buttons[1] != null and buttons[2] != null:
		return
	buttons = [
		get_node_or_null("PanelContainer/VBoxContainer/Button1"),
		get_node_or_null("PanelContainer/VBoxContainer/Button2"),
		get_node_or_null("PanelContainer/VBoxContainer/Button3"),
	]
