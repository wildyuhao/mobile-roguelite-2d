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
	for index in range(buttons.size()):
		buttons[index].pressed.connect(_on_button_pressed.bind(index))
	hide()

func show_choices(choices: Array[Dictionary]) -> void:
	current_choices = choices
	for index in range(buttons.size()):
		var button := buttons[index]
		if index < choices.size():
			button.text = choices[index].get("display_name", choices[index].get("id", "Upgrade"))
			button.disabled = false
		else:
			button.text = "-"
			button.disabled = true
	show()

func _on_button_pressed(index: int) -> void:
	if index >= current_choices.size():
		return

	var selected := current_choices[index]
	hide()
	upgrade_selected.emit(selected)
