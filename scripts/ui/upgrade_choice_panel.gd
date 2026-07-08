extends CanvasLayer
class_name UpgradeChoicePanel

signal upgrade_selected(upgrade: Dictionary)

@onready var buttons: Array[Button] = [
	$PanelContainer/VBoxContainer/Button1,
	$PanelContainer/VBoxContainer/Button2,
	$PanelContainer/VBoxContainer/Button3,
]

var current_choices: Array[Dictionary] = []

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
			button.disabled = false
		else:
			button.text = "-"
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
	var label := String(choice.get("display_name", choice.get("id", "Upgrade")))
	var summary := String(choice.get("effect_summary", ""))
	if summary == "":
		return label
	return "%s\n%s" % [label, summary]

func _resolve_buttons() -> void:
	if buttons.size() == 3 and buttons[0] != null and buttons[1] != null and buttons[2] != null:
		return
	buttons = [
		get_node_or_null("PanelContainer/VBoxContainer/Button1"),
		get_node_or_null("PanelContainer/VBoxContainer/Button2"),
		get_node_or_null("PanelContainer/VBoxContainer/Button3"),
	]
