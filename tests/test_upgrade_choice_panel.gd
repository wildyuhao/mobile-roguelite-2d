extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/UpgradeChoicePanel.tscn"):
		runner.assert_true(false, "upgrade choice panel scene should exist")
		return

	var panel_scene: PackedScene = load("res://scenes/ui/UpgradeChoicePanel.tscn")
	var panel = panel_scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)

	if panel.has_method("show_choices"):
		var choices: Array[Dictionary] = [
			{
				"id": "weapon_damage_1",
				"display_name": "锋刃淬炼",
				"effect_summary": "伤害 +15%",
			},
			{
				"id": "cooldown_1",
				"display_name": "迅捷敕令",
				"effect_summary": "冷却 -8%",
			},
			{
				"id": "unlock_talisman_fire",
				"display_name": "习得符火",
			},
		]
		panel.show_choices(choices)
		runner.assert_true(panel.has_node("PanelContainer/VBoxContainer/TitleLabel"), "upgrade choice panel should include a title")
		runner.assert_true(panel.has_node("PanelContainer/VBoxContainer/SubtitleLabel"), "upgrade choice panel should include a paused-state subtitle")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/TitleLabel").text, "选择强化", "panel title should be Chinese")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/SubtitleLabel").text, "战斗暂停", "panel subtitle should be Chinese")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button1").text, "锋刃淬炼\n伤害 +15%", "first choice should be Chinese")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button2").text, "迅捷敕令\n冷却 -8%", "second choice should be Chinese")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button3").text, "习得符火", "name-only choice should be Chinese")
		runner.assert_true(panel.get_node("PanelContainer/VBoxContainer/Button1").custom_minimum_size.y >= 96.0, "first choice button should be a large mobile touch target")
		runner.assert_true(panel.get_node("PanelContainer/VBoxContainer/Button2").custom_minimum_size.y >= 96.0, "second choice button should be a large mobile touch target")
		runner.assert_true(panel.get_node("PanelContainer/VBoxContainer/Button3").custom_minimum_size.y >= 96.0, "third choice button should be a large mobile touch target")
		var no_choices: Array[Dictionary] = []
		panel.show_choices(no_choices)
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button1").text, "无可用强化", "missing choices should use Chinese fallback")
	else:
		runner.assert_true(false, "upgrade choice panel should expose show_choices")

	panel.queue_free()
