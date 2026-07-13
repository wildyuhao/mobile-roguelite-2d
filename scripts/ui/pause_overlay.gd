extends CanvasLayer
class_name PauseOverlay

signal pause_requested
signal resume_requested
signal restart_requested

@onready var pause_button: TextureButton = $PauseButton
@onready var pause_screen: Control = $PauseScreen
@onready var resume_button: Button = $PauseScreen/PanelContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $PauseScreen/PanelContainer/VBoxContainer/RestartButton

var pause_available: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_nodes()
	_connect_buttons()
	pause_screen.hide()
	pause_button.show()

func show_pause() -> void:
	_resolve_nodes()
	pause_screen.show()
	pause_button.hide()

func hide_pause() -> void:
	_resolve_nodes()
	pause_screen.hide()
	pause_button.visible = pause_available

func set_pause_available(available: bool) -> void:
	_resolve_nodes()
	pause_available = available
	if not available:
		pause_screen.hide()
		pause_button.hide()
		return
	if pause_screen.visible:
		pause_button.hide()
	else:
		pause_button.show()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if pause_screen.visible:
		resume_requested.emit()
	elif pause_available:
		pause_requested.emit()

func _connect_buttons() -> void:
	if not pause_button.pressed.is_connected(_on_pause_pressed):
		pause_button.pressed.connect(_on_pause_pressed)
	if not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)

func _on_pause_pressed() -> void:
	pause_requested.emit()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _resolve_nodes() -> void:
	if pause_button == null:
		pause_button = get_node_or_null("PauseButton")
	if pause_screen == null:
		pause_screen = get_node_or_null("PauseScreen")
	if resume_button == null:
		resume_button = get_node_or_null("PauseScreen/PanelContainer/VBoxContainer/ResumeButton")
	if restart_button == null:
		restart_button = get_node_or_null("PauseScreen/PanelContainer/VBoxContainer/RestartButton")
