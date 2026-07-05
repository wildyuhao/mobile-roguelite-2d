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

	panel.queue_free()
