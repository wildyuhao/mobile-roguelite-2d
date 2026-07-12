extends CanvasLayer
class_name SettlementPanel

signal restart_requested
signal upgrade_requested(equipment_id: String)

@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var materials_label: Label = $PanelContainer/VBoxContainer/MaterialsLabel
@onready var material_bonus_label: Label = $PanelContainer/VBoxContainer/MaterialBonusLabel
@onready var defeated_label: Label = $PanelContainer/VBoxContainer/DefeatedLabel
@onready var boss_label: Label = $PanelContainer/VBoxContainer/BossLabel
@onready var total_materials_label: Label = $PanelContainer/VBoxContainer/TotalMaterialsLabel
@onready var upgrade_feedback_label: Label = $PanelContainer/VBoxContainer/UpgradeFeedbackLabel
@onready var upgrade_label: Label = $PanelContainer/VBoxContainer/UpgradeLabel
@onready var upgrade_button: Button = $PanelContainer/VBoxContainer/UpgradeButton
@onready var upgrade_route_labels: Array[Label] = [
	$PanelContainer/VBoxContainer/UpgradeRow1/UpgradeRouteLabel1,
	$PanelContainer/VBoxContainer/UpgradeRow2/UpgradeRouteLabel2,
	$PanelContainer/VBoxContainer/UpgradeRow3/UpgradeRouteLabel3,
	$PanelContainer/VBoxContainer/UpgradeRow4/UpgradeRouteLabel4,
]
@onready var upgrade_labels: Array[Label] = [
	$PanelContainer/VBoxContainer/UpgradeRow1/UpgradeLabel1,
	$PanelContainer/VBoxContainer/UpgradeRow2/UpgradeLabel2,
	$PanelContainer/VBoxContainer/UpgradeRow3/UpgradeLabel3,
	$PanelContainer/VBoxContainer/UpgradeRow4/UpgradeLabel4,
]
@onready var upgrade_buttons: Array[Button] = [
	$PanelContainer/VBoxContainer/UpgradeRow1/UpgradeButton1,
	$PanelContainer/VBoxContainer/UpgradeRow2/UpgradeButton2,
	$PanelContainer/VBoxContainer/UpgradeRow3/UpgradeButton3,
	$PanelContainer/VBoxContainer/UpgradeRow4/UpgradeButton4,
]
@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton

var upgrade_equipment_id: String = ""
var upgrade_offer_ids: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_nodes()
	hide()

func show_result(title: String, rewards: Dictionary, _summary: Dictionary) -> void:
	_resolve_nodes()
	title_label.text = title
	materials_label.text = "灵石 +%d" % int(rewards.get("materials", 0))
	var material_bonus := int(rewards.get("material_bonus", 0))
	material_bonus_label.visible = material_bonus > 0
	material_bonus_label.text = "灵石加成 +%d" % material_bonus
	defeated_label.text = "击败敌人 %d" % int(rewards.get("defeated_enemies", 0))
	boss_label.text = "首领已封印" if bool(rewards.get("boss_defeated", false)) else "首领逃脱"
	if upgrade_feedback_label != null:
		upgrade_feedback_label.text = ""
		upgrade_feedback_label.hide()
	show()

func show_upgrade_feedback(display_name: String, level: int) -> void:
	_resolve_nodes()
	if upgrade_feedback_label == null:
		return
	upgrade_feedback_label.text = "已强化：%s %d级" % [display_name, level]
	upgrade_feedback_label.show()

func show_upgrade_offer(equipment_id: String, display_name: String, level: int, cost: int, total_materials: int, can_upgrade: bool) -> void:
	_resolve_nodes()
	upgrade_equipment_id = equipment_id
	total_materials_label.text = "持有灵石 %d" % total_materials
	upgrade_label.text = "%s %d级" % [display_name, level]
	upgrade_button.text = "强化 %d" % cost
	upgrade_button.disabled = not can_upgrade
	show_upgrade_offers([
		{
			"equipment_id": equipment_id,
			"display_name": display_name,
			"level": level,
			"cost": cost,
			"total_materials": total_materials,
			"can_upgrade": can_upgrade,
		}
	])

func show_upgrade_offers(offers: Array) -> void:
	_resolve_nodes()
	if upgrade_label != null:
		upgrade_label.hide()
	if upgrade_button != null:
		upgrade_button.hide()
	upgrade_offer_ids.clear()
	var total_materials := 0
	if not offers.is_empty():
		total_materials = int(offers[0].get("total_materials", 0))
	total_materials_label.text = "持有灵石 %d" % total_materials

	for index in range(upgrade_buttons.size()):
		var route_label := upgrade_route_labels[index]
		var label := upgrade_labels[index]
		var button := upgrade_buttons[index]
		if index < offers.size():
			var offer: Dictionary = offers[index]
			upgrade_offer_ids.append(offer.get("equipment_id", ""))
			_apply_route_label(route_label, offer)
			label.text = _format_offer_label(offer)
			button.text = "强化 %d" % int(offer.get("cost", 0))
			button.disabled = not bool(offer.get("can_upgrade", false))
		else:
			upgrade_offer_ids.append("")
			route_label.hide()
			label.text = "-"
			button.text = "强化"
			button.disabled = true

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_upgrade_pressed() -> void:
	if upgrade_equipment_id == "" or (upgrade_button != null and upgrade_button.disabled):
		return
	upgrade_requested.emit(upgrade_equipment_id)

func _on_upgrade_offer_pressed(index: int) -> void:
	if index < 0 or index >= upgrade_offer_ids.size():
		return
	if upgrade_buttons[index].disabled:
		return
	var equipment_id := upgrade_offer_ids[index]
	if equipment_id == "":
		return
	upgrade_requested.emit(equipment_id)

func _resolve_nodes() -> void:
	if title_label == null:
		title_label = get_node_or_null("PanelContainer/VBoxContainer/TitleLabel")
	if materials_label == null:
		materials_label = get_node_or_null("PanelContainer/VBoxContainer/MaterialsLabel")
	if material_bonus_label == null:
		material_bonus_label = get_node_or_null("PanelContainer/VBoxContainer/MaterialBonusLabel")
	if defeated_label == null:
		defeated_label = get_node_or_null("PanelContainer/VBoxContainer/DefeatedLabel")
	if boss_label == null:
		boss_label = get_node_or_null("PanelContainer/VBoxContainer/BossLabel")
	if total_materials_label == null:
		total_materials_label = get_node_or_null("PanelContainer/VBoxContainer/TotalMaterialsLabel")
	if upgrade_feedback_label == null:
		upgrade_feedback_label = get_node_or_null("PanelContainer/VBoxContainer/UpgradeFeedbackLabel")
	if upgrade_label == null:
		upgrade_label = get_node_or_null("PanelContainer/VBoxContainer/UpgradeLabel")
	if upgrade_button == null:
		upgrade_button = get_node_or_null("PanelContainer/VBoxContainer/UpgradeButton")
	if upgrade_route_labels.is_empty():
		upgrade_route_labels = [
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow1/UpgradeRouteLabel1"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow2/UpgradeRouteLabel2"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow3/UpgradeRouteLabel3"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow4/UpgradeRouteLabel4"),
		]
	if upgrade_labels.is_empty():
		upgrade_labels = [
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow1/UpgradeLabel1"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow2/UpgradeLabel2"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow3/UpgradeLabel3"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow4/UpgradeLabel4"),
		]
	if upgrade_buttons.is_empty():
		upgrade_buttons = [
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow1/UpgradeButton1"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow2/UpgradeButton2"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow3/UpgradeButton3"),
			get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow4/UpgradeButton4"),
		]
	if restart_button == null:
		restart_button = get_node_or_null("PanelContainer/VBoxContainer/RestartButton")
	if upgrade_button != null and not upgrade_button.pressed.is_connected(_on_upgrade_pressed):
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	for index in range(upgrade_buttons.size()):
		if upgrade_buttons[index] != null and not upgrade_buttons[index].pressed.is_connected(_on_upgrade_offer_pressed.bind(index)):
			upgrade_buttons[index].pressed.connect(_on_upgrade_offer_pressed.bind(index))
	if restart_button != null and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)

func _format_offer_label(offer: Dictionary) -> String:
	var label := "%s %d级" % [offer.get("display_name", offer.get("equipment_id", "装备")), int(offer.get("level", 1))]
	var summary := String(offer.get("stat_summary", ""))
	if summary == "":
		return label
	return "%s · %s" % [label, summary]

func _apply_route_label(route_label: Label, offer: Dictionary) -> void:
	var route_text := String(offer.get("route_label", ""))
	if route_text == "":
		route_label.hide()
		return
	route_label.show()
	route_label.text = route_text
	route_label.modulate = Color.html(String(offer.get("route_color", "#ffffff")))
