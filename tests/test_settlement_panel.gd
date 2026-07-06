extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/SettlementPanel.tscn"):
		runner.assert_true(false, "settlement panel scene should exist")
		return

	var panel_scene: PackedScene = load("res://scenes/ui/SettlementPanel.tscn")
	var panel = panel_scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)

	if panel.has_method("show_result"):
		panel.show_result("Run Failed", {
			"materials": 10,
			"defeated_enemies": 3,
			"boss_defeated": false,
		}, {
			"player_defeated": true,
		})
		runner.assert_true(panel.visible, "settlement panel should be visible after show_result")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/TitleLabel").text, "Run Failed", "panel should show result title")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/MaterialsLabel").text, "Materials +10", "panel should show materials")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/DefeatedLabel").text, "Defeated 3", "panel should show defeated count")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/BossLabel").text, "Boss Escaped", "panel should show boss status")
		var material_bonus_label = panel.get_node_or_null("PanelContainer/VBoxContainer/MaterialBonusLabel")
		runner.assert_true(material_bonus_label != null, "settlement panel should include material bonus label")
		if material_bonus_label != null:
			runner.assert_true(not material_bonus_label.visible, "material bonus label should hide when there is no bonus")
		panel.show_result("Boss Sealed", {
			"materials": 49,
			"material_bonus": 10,
			"defeated_enemies": 12,
			"boss_defeated": true,
		}, {})
		if material_bonus_label != null:
			runner.assert_true(material_bonus_label.visible, "material bonus label should show when there is a bonus")
			runner.assert_eq(material_bonus_label.text, "Material Bonus +10", "panel should show material bonus amount")
	else:
		runner.assert_true(false, "settlement panel should expose show_result")

	var restart_count := [0]
	if panel.has_signal("restart_requested"):
		panel.restart_requested.connect(func() -> void: restart_count[0] += 1)
		panel.get_node("PanelContainer/VBoxContainer/RestartButton").pressed.emit()
		runner.assert_eq(restart_count[0], 1, "restart button should emit restart_requested")
	else:
		runner.assert_true(false, "settlement panel should expose restart_requested")

	var upgrade_requests: Array[String] = []
	if panel.has_signal("upgrade_requested") and panel.has_method("show_upgrade_offer"):
		panel.upgrade_requested.connect(func(equipment_id: String) -> void: upgrade_requests.append(equipment_id))
		panel.show_upgrade_offer("talisman_robe", "Talisman Robe", 2, 20, 30, true)
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/TotalMaterialsLabel").text, "Materials 30", "panel should show total saved materials")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeLabel").text, "Talisman Robe Lv.2", "panel should show equipment level")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").text, "Upgrade 20", "panel should show upgrade cost")
		runner.assert_true(not panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").disabled, "upgrade button should be enabled when affordable")
		panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").pressed.emit()
		runner.assert_eq(upgrade_requests.size(), 1, "upgrade button should emit one request")
		runner.assert_eq(upgrade_requests[0], "talisman_robe", "upgrade request should include equipment id")
		panel.show_upgrade_offer("talisman_robe", "Talisman Robe", 2, 20, 5, false)
		runner.assert_true(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").disabled, "upgrade button should disable when unaffordable")
	else:
		runner.assert_true(false, "settlement panel should expose an equipment upgrade offer")

	if panel.has_method("show_upgrade_offers"):
		panel.show_upgrade_offers([
			{
				"equipment_id": "talisman_robe",
				"display_name": "Talisman Robe",
				"level": 2,
				"cost": 20,
				"total_materials": 30,
				"can_upgrade": true,
			},
			{
				"equipment_id": "cloudstep_boots",
				"display_name": "Cloudstep Boots",
				"level": 1,
				"cost": 10,
				"total_materials": 30,
				"can_upgrade": true,
			},
			{
				"equipment_id": "bronze_gear_core",
				"display_name": "Bronze Gear Core",
				"level": 4,
				"cost": 40,
				"total_materials": 30,
				"can_upgrade": false,
			},
			{
				"equipment_id": "jade_compass",
				"display_name": "Jade Compass",
				"level": 1,
				"cost": 10,
				"total_materials": 30,
				"can_upgrade": true,
			},
		])
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeLabel1").text, "Talisman Robe Lv.2", "first offer should show robe")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton1").text, "Upgrade 20", "first offer should show cost")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeLabel2").text, "Cloudstep Boots Lv.1", "second offer should show boots")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton2").text, "Upgrade 10", "second offer should show cost")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/UpgradeLabel3").text, "Bronze Gear Core Lv.4", "third offer should show gear core")
		runner.assert_true(panel.get_node("PanelContainer/VBoxContainer/UpgradeButton3").disabled, "third offer should be disabled when unaffordable")
		var fourth_label = panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeLabel4")
		var fourth_button = panel.get_node_or_null("PanelContainer/VBoxContainer/UpgradeButton4")
		runner.assert_true(fourth_label != null, "settlement panel should include fourth offer label")
		runner.assert_true(fourth_button != null, "settlement panel should include fourth offer button")
		if fourth_label != null:
			runner.assert_eq(fourth_label.text, "Jade Compass Lv.1", "fourth offer should show compass")
		if fourth_button != null:
			runner.assert_eq(fourth_button.text, "Upgrade 10", "fourth offer should show cost")
		runner.assert_true(not panel.get_node("PanelContainer/VBoxContainer/UpgradeButton").visible, "multi-offer mode should hide the legacy single upgrade button")
		panel.get_node("PanelContainer/VBoxContainer/UpgradeButton2").pressed.emit()
		runner.assert_eq(upgrade_requests.back(), "cloudstep_boots", "second upgrade button should emit its equipment id")
		if fourth_button != null:
			fourth_button.pressed.emit()
			runner.assert_eq(upgrade_requests.back(), "jade_compass", "fourth upgrade button should emit its equipment id")
	else:
		runner.assert_true(false, "settlement panel should expose multiple equipment upgrade offers")

	panel.queue_free()
