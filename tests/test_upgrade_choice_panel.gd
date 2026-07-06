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
				"display_name": "Sharpened Edge",
				"effect_summary": "Damage +15%",
			},
			{
				"id": "cooldown_1",
				"display_name": "Quick Invocation",
				"effect_summary": "CD -8%",
			},
			{
				"id": "unlock_talisman_fire",
				"display_name": "Learn Talisman Fire",
			},
		]
		panel.show_choices(choices)
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button1").text, "Sharpened Edge - Damage +15%", "first choice button should include effect summary")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button2").text, "Quick Invocation - CD -8%", "second choice button should include effect summary")
		runner.assert_eq(panel.get_node("PanelContainer/VBoxContainer/Button3").text, "Learn Talisman Fire", "choice without summary should keep name-only text")
	else:
		runner.assert_true(false, "upgrade choice panel should expose show_choices")

	panel.queue_free()
