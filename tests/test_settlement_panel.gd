extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/SettlementPanel.tscn"):
		runner.assert_true(false, "settlement panel scene should exist")
		return

	var panel_scene: PackedScene = load("res://scenes/ui/SettlementPanel.tscn")
	var panel = panel_scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)

	if panel.has_method("show_result"):
		panel.show_result("挑战失败", {
			"materials": 10,
			"defeated_enemies": 3,
			"boss_defeated": false,
		}, {
			"player_defeated": true,
		})
		runner.assert_true(panel.visible, "settlement panel should be visible after show_result")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/TitleLabel").text, "挑战失败", "panel should show result title")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/MaterialsLabel").text, "灵石 +10", "panel should show materials")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/DefeatedLabel").text, "击败敌人 3", "panel should show defeated count")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/BossLabel").text, "首领逃脱", "panel should show boss status")
		var material_bonus_label = panel.get_node_or_null("PanelContainer/VBoxContainer/MaterialBonusLabel")
		runner.assert_true(material_bonus_label != null, "settlement panel should include material bonus label")
		if material_bonus_label != null:
			runner.assert_true(not material_bonus_label.visible, "material bonus label should hide when there is no bonus")
		var upgrade_feedback_label = panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeFeedbackLabel")
		runner.assert_true(upgrade_feedback_label != null, "settlement panel should include upgrade feedback label")
		if upgrade_feedback_label != null:
			runner.assert_true(not upgrade_feedback_label.visible, "upgrade feedback should hide before an upgrade succeeds")
			runner.assert_eq(upgrade_feedback_label.text, "", "upgrade feedback should reset when showing a result")
		panel.show_result("封印成功", {
			"materials": 49,
			"material_bonus": 10,
			"defeated_enemies": 12,
			"boss_defeated": true,
		}, {})
		if material_bonus_label != null:
			runner.assert_true(material_bonus_label.visible, "material bonus label should show when there is a bonus")
			runner.assert_eq(material_bonus_label.text, "灵石加成 +10", "panel should show material bonus amount")
		if panel.has_method("show_upgrade_feedback") and upgrade_feedback_label != null:
			panel.show_upgrade_feedback("踏云靴", 2)
			runner.assert_true(upgrade_feedback_label.visible, "upgrade feedback should show after a successful upgrade")
			runner.assert_eq(upgrade_feedback_label.text, "已强化：踏云靴 2级", "upgrade feedback should show the upgraded equipment and level")
			panel.show_result("挑战失败", {
				"materials": 3,
				"defeated_enemies": 1,
				"boss_defeated": false,
			}, {})
			runner.assert_true(not upgrade_feedback_label.visible, "upgrade feedback should reset on a new settlement result")
			runner.assert_eq(upgrade_feedback_label.text, "", "upgrade feedback text should clear on a new settlement result")
		else:
			runner.assert_true(false, "settlement panel should expose show_upgrade_feedback")
	else:
		runner.assert_true(false, "settlement panel should expose show_result")

	var restart_count := [0]
	if panel.has_signal("restart_requested"):
		panel.restart_requested.connect(func() -> void: restart_count[0] += 1)
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/RestartButton").text, "重新挑战", "restart button should use Chinese copy")
		panel.get_node("PanelContainer/VBoxContainer/RestartButton").pressed.emit()
		runner.assert_eq(restart_count[0], 1, "restart button should emit restart_requested")
	else:
		runner.assert_true(false, "settlement panel should expose restart_requested")

	var upgrade_requests: Array[String] = []
	if panel.has_signal("upgrade_requested") and panel.has_method("show_upgrade_offer"):
		panel.upgrade_requested.connect(func(equipment_id: String) -> void: upgrade_requests.append(equipment_id))
		panel.show_upgrade_offer("talisman_robe", "符甲法袍", 2, 20, 30, true)
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/TotalMaterialsLabel").text, "持有灵石 30", "panel should show total saved materials")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeLabel").text, "符甲法袍 2级", "panel should show equipment level")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").text, "强化 20", "panel should show upgrade cost")
		runner.assert_true(not panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").disabled, "upgrade button should be enabled when affordable")
		panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").pressed.emit()
		runner.assert_eq(upgrade_requests.size(), 1, "upgrade button should emit one request")
		runner.assert_eq(upgrade_requests[0], "talisman_robe", "upgrade request should include equipment id")
		panel.show_upgrade_offer("talisman_robe", "符甲法袍", 2, 20, 5, false)
		runner.assert_true(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").disabled, "upgrade button should disable when unaffordable")
	else:
		runner.assert_true(false, "settlement panel should expose an equipment upgrade offer")

	if panel.has_method("show_upgrade_offers"):
		panel.show_upgrade_offers([
			{
				"equipment_id": "talisman_robe",
				"display_name": "符甲法袍",
				"level": 2,
				"cost": 20,
				"total_materials": 30,
				"can_upgrade": true,
				"stat_summary": "生命 +10",
				"route_label": "生命",
				"route_color": "#ff8a8a",
			},
			{
				"equipment_id": "cloudstep_boots",
				"display_name": "踏云靴",
				"level": 1,
				"cost": 10,
				"total_materials": 30,
				"can_upgrade": true,
				"stat_summary": "移速 +18",
				"route_label": "移速",
				"route_color": "#8fd6ff",
			},
			{
				"equipment_id": "bronze_gear_core",
				"display_name": "机关核心",
				"level": 4,
				"cost": 40,
				"total_materials": 30,
				"can_upgrade": false,
				"stat_summary": "冷却 -5%",
				"route_label": "冷却",
				"route_color": "#ffd166",
			},
			{
				"equipment_id": "jade_compass",
				"display_name": "聚灵盘",
				"level": 1,
				"cost": 10,
				"total_materials": 30,
				"can_upgrade": true,
				"stat_summary": "拾取 +24，灵石 +10%",
				"route_label": "聚灵",
				"route_color": "#8df0a9",
			},
		])
		var row1 = _get_offer_row(panel, 1)
		var row2 = _get_offer_row(panel, 2)
		var row3 = _get_offer_row(panel, 3)
		var row4 = _get_offer_row(panel, 4)
		runner.assert_true(row1 is HBoxContainer, "first settlement offer should use a compact row")
		runner.assert_true(row2 is HBoxContainer, "second settlement offer should use a compact row")
		runner.assert_true(row3 is HBoxContainer, "third settlement offer should use a compact row")
		runner.assert_true(row4 is HBoxContainer, "fourth settlement offer should use a compact row")
		var label1 = _get_offer_label(panel, 1)
		var label2 = _get_offer_label(panel, 2)
		var label3 = _get_offer_label(panel, 3)
		var route1 = _get_route_label(panel, 1)
		var route2 = _get_route_label(panel, 2)
		var route3 = _get_route_label(panel, 3)
		var route4 = _get_route_label(panel, 4)
		var button1 = _get_offer_button(panel, 1)
		var button2 = _get_offer_button(panel, 2)
		var button3 = _get_offer_button(panel, 3)
		var fourth_label = _get_offer_label(panel, 4)
		var fourth_button = _get_offer_button(panel, 4)
		runner.assert_true(route1 != null, "first offer should include a route tag")
		runner.assert_true(route2 != null, "second offer should include a route tag")
		runner.assert_true(route3 != null, "third offer should include a route tag")
		runner.assert_true(route4 != null, "fourth offer should include a route tag")
		if route1 != null:
			runner.assert_eq(route1.text, "生命", "first route tag should show health route")
			runner.assert_true(route1.custom_minimum_size.x >= 48.0, "first route tag should keep a stable scan width")
		if route2 != null:
			runner.assert_eq(route2.text, "移速", "second route tag should show speed route")
			runner.assert_true(route2.custom_minimum_size.x >= 48.0, "second route tag should keep a stable scan width")
		if route3 != null:
			runner.assert_eq(route3.text, "冷却", "third route tag should show cooldown route")
			runner.assert_true(route3.custom_minimum_size.x >= 48.0, "third route tag should keep a stable scan width")
		if route4 != null:
			runner.assert_eq(route4.text, "聚灵", "fourth route tag should show loot route")
			runner.assert_true(route4.custom_minimum_size.x >= 48.0, "fourth route tag should keep a stable scan width")
		runner.assert_true(label1 != null, "first offer should include a label")
		runner.assert_true(button1 != null, "first offer should include a button")
		if label1 != null:
			runner.assert_eq(label1.text, "符甲法袍 2级 · 生命 +10", "first offer should show robe")
		if button1 != null:
			runner.assert_eq(button1.text, "强化 20", "first offer should show cost")
			runner.assert_true(button1.custom_minimum_size.x >= 112.0, "first offer upgrade button should keep a stable tap width")
		if label2 != null:
			runner.assert_eq(label2.text, "踏云靴 1级 · 移速 +18", "second offer should show boots")
		if button2 != null:
			runner.assert_eq(button2.text, "强化 10", "second offer should show cost")
			runner.assert_true(button2.custom_minimum_size.x >= 112.0, "second offer upgrade button should keep a stable tap width")
		if label3 != null:
			runner.assert_eq(label3.text, "机关核心 4级 · 冷却 -5%", "third offer should show gear core")
		if button3 != null:
			runner.assert_true(button3.disabled, "third offer should be disabled when unaffordable")
			runner.assert_true(button3.custom_minimum_size.x >= 112.0, "third offer upgrade button should keep a stable tap width")
		runner.assert_true(fourth_label != null, "settlement panel should include fourth offer label")
		runner.assert_true(fourth_button != null, "settlement panel should include fourth offer button")
		if fourth_label != null:
			runner.assert_eq(fourth_label.text, "聚灵盘 1级 · 拾取 +24，灵石 +10%", "fourth offer should show compass")
		if fourth_button != null:
			runner.assert_eq(fourth_button.text, "强化 10", "fourth offer should show cost")
			runner.assert_true(fourth_button.custom_minimum_size.x >= 112.0, "fourth offer upgrade button should keep a stable tap width")
		runner.assert_true(not panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").visible, "multi-offer mode should hide the legacy single upgrade button")
		if button2 != null:
			button2.pressed.emit()
		runner.assert_eq(upgrade_requests.back(), "cloudstep_boots", "second upgrade button should emit its equipment id")
		if fourth_button != null:
			fourth_button.pressed.emit()
			runner.assert_eq(upgrade_requests.back(), "jade_compass", "fourth upgrade button should emit its equipment id")
	else:
		runner.assert_true(false, "settlement panel should expose multiple equipment upgrade offers")

	panel.queue_free()

func _get_offer_row(panel: Node, index: int) -> Node:
	return panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow%d" % index)

func _get_offer_label(panel: Node, index: int) -> Label:
	return panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow%d/UpgradeLabel%d" % [index, index]) as Label

func _get_route_label(panel: Node, index: int) -> Label:
	return panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow%d/UpgradeRouteLabel%d" % [index, index]) as Label

func _get_offer_button(panel: Node, index: int) -> Button:
	return panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeRow%d/UpgradeButton%d" % [index, index]) as Button
