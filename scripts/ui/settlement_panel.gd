extends CanvasLayer
class_name SettlementPanel

signal restart_requested
signal upgrade_requested(equipment_id: String)

@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var materials_label: Label = $PanelContainer/VBoxContainer/MaterialsLabel
@onready var defeated_label: Label = $PanelContainer/VBoxContainer/DefeatedLabel
@onready var boss_label: Label = $PanelContainer/VBoxContainer/BossLabel
@onready var total_materials_label: Label = $PanelContainer/VBoxContainer/TotalMaterialsLabel
@onready var upgrade_label: Label = $PanelContainer/VBoxContainer/UpgradeLabel
@onready var upgrade_button: Button = $PanelContainer/VBoxContainer/UpgradeButton
@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton

var upgrade_equipment_id: String = ""

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

func show_upgrade_offer(equipment_id: String, display_name: String, level: int, cost: int, total_materials: int, can_upgrade: bool) -> void:
	_resolve_nodes()
	upgrade_equipment_id = equipment_id
	total_materials_label.text = "Materials %d" % total_materials
	upgrade_label.text = "%s Lv.%d" % [display_name, level]
	upgrade_button.text = "Upgrade %d" % cost
	upgrade_button.disabled = not can_upgrade

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_upgrade_pressed() -> void:
	if upgrade_equipment_id == "" or (upgrade_button != null and upgrade_button.disabled):
		return
	upgrade_requested.emit(upgrade_equipment_id)

func _resolve_nodes() -> void:
	if title_label == null:
		title_label = get_node_or_null("PanelContainer/VBoxContainer/TitleLabel")
	if materials_label == null:
		materials_label = get_node_or_null("PanelContainer/VBoxContainer/MaterialsLabel")
	if defeated_label == null:
		defeated_label = get_node_or_null("PanelContainer/VBoxContainer/DefeatedLabel")
	if boss_label == null:
		boss_label = get_node_or_null("PanelContainer/VBoxContainer/BossLabel")
	if total_materials_label == null:
		total_materials_label = get_node_or_null("PanelContainer/VBoxContainer/TotalMaterialsLabel")
	if upgrade_label == null:
		upgrade_label = get_node_or_null("PanelContainer/VBoxContainer/UpgradeLabel")
	if upgrade_button == null:
		upgrade_button = get_node_or_null("PanelContainer/VBoxContainer/UpgradeButton")
	if restart_button == null:
		restart_button = get_node_or_null("PanelContainer/VBoxContainer/RestartButton")
	if upgrade_button != null and not upgrade_button.pressed.is_connected(_on_upgrade_pressed):
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
