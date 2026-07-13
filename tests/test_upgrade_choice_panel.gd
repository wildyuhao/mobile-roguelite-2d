extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/UpgradeChoicePanel.tscn"):
		runner.assert_true(false, "upgrade choice panel scene should exist")
		return

	var panel_scene: PackedScene = load("res://scenes/ui/UpgradeChoicePanel.tscn")
	var panel = panel_scene.instantiate()
	Engine.get_main_loop().root.add_child(panel)

	if not panel.has_method("show_choices"):
		runner.assert_true(false, "upgrade choice panel should expose show_choices")
		panel.queue_free()
		return

	var choices: Array[Dictionary] = [
		{
			"id": "weapon_damage_1",
			"display_name": "锋刃淬炼",
			"effect_summary": "伤害 +15%",
			"category_label": "功法强化",
			"progress_label": "第2重",
			"icon_path": "res://art/icons/icon_flying_sword.png",
		},
		{
			"id": "cooldown_1",
			"display_name": "迅捷敕令",
			"effect_summary": "冷却 -8%",
			"category_label": "功法强化",
			"progress_label": "第1重",
			"icon_path": "res://art/icons/missing_upgrade_icon.png",
		},
		{
			"id": "unlock_talisman_fire",
			"display_name": "习得符火",
			"category_label": "新武器",
			"progress_label": "Lv.1",
			"icon_path": "res://art/icons/icon_talisman_fire.png",
		},
	]
	panel.show_choices(choices)
	runner.assert_true(panel.has_node("PanelContainer/VBoxContainer/TitleLabel"), "upgrade choice panel should include a title")
	runner.assert_true(panel.has_node("PanelContainer/VBoxContainer/SubtitleLabel"), "upgrade choice panel should include a paused-state subtitle")
	runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/TitleLabel").text, "选择强化", "panel title should be Chinese")
	runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/SubtitleLabel").text, "战斗暂停", "panel subtitle should be Chinese")

	var button1: Button = panel.get_node("PanelContainer/VBoxContainer/Button1")
	var button2: Button = panel.get_node("PanelContainer/VBoxContainer/Button2")
	var button3: Button = panel.get_node("PanelContainer/VBoxContainer/Button3")
	runner.assert_eq(button1.text, "功法强化 · 第2重\n锋刃淬炼\n伤害 +15%", "choice should expose category, progress, name and effect")
	runner.assert_eq(button2.text, "功法强化 · 第1重\n迅捷敕令\n冷却 -8%", "second choice should keep three readable lines")
	runner.assert_eq(button3.text, "新武器 · Lv.1\n习得符火", "name-only choice should keep category and progress")
	runner.assert_true(button1.icon is Texture2D, "valid choice icon should load")
	runner.assert_eq(button2.icon, null, "invalid icon should fall back to text only")
	runner.assert_true(button3.icon is Texture2D, "second valid choice icon should load")

	for button in [button1, button2, button3]:
		runner.assert_true(button.custom_minimum_size.y >= 116.0, "choice button should be a large mobile touch target")
		runner.assert_true(button.expand_icon, "choice icon should scale inside its bound")
		runner.assert_eq(
			button.get_theme_constant("icon_max_width"),
			68,
			"choice icon should have a stable width"
		)
		runner.assert_eq(button.alignment, HORIZONTAL_ALIGNMENT_LEFT, "choice text should scan from the left")
		runner.assert_true(button.clip_text, "long summaries should stay inside the choice")
		runner.assert_true(
			button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING,
			"long summaries should trim instead of resizing the choice"
		)

	var no_choices: Array[Dictionary] = []
	panel.show_choices(no_choices)
	runner.assert_eq(button1.text, "无可用强化", "missing choices should use Chinese fallback")
	runner.assert_eq(button1.icon, null, "button reuse should clear stale icons")
	runner.assert_true(button1.disabled, "missing choice should disable its button")
	panel.queue_free()
