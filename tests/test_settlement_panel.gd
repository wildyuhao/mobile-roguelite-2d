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

	panel.queue_free()
