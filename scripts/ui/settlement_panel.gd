extends CanvasLayer
class_name SettlementPanel

signal restart_requested

@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var materials_label: Label = $PanelContainer/VBoxContainer/MaterialsLabel
@onready var defeated_label: Label = $PanelContainer/VBoxContainer/DefeatedLabel
@onready var boss_label: Label = $PanelContainer/VBoxContainer/BossLabel
@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_nodes()
	hide()

func show_result(title: String, rewards: Dictionary, _summary: Dictionary) -> void:
	_resolve_nodes()
	title_label.text = title
	materials_label.text = "Materials +%d" % int(rewards.get("materials", 0))
	defeated_label.text = "Defeated %d" % int(rewards.get("defeated_enemies", 0))
	boss_label.text = "Boss Sealed" if bool(rewards.get("boss_defeated", false)) else "Boss Escaped"
	show()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _resolve_nodes() -> void:
	if title_label == null:
		title_label = get_node_or_null("PanelContainer/VBoxContainer/TitleLabel")
	if materials_label == null:
		materials_label = get_node_or_null("PanelContainer/VBoxContainer/MaterialsLabel")
	if defeated_label == null:
		defeated_label = get_node_or_null("PanelContainer/VBoxContainer/DefeatedLabel")
	if boss_label == null:
		boss_label = get_node_or_null("PanelContainer/VBoxContainer/BossLabel")
	if restart_button == null:
		restart_button = get_node_or_null("PanelContainer/VBoxContainer/RestartButton")
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
