extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		runner.assert_true(false, "HUD scene should exist")
		return

	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	var hud = hud_scene.instantiate()
	Engine.get_main_loop().root.add_child(hud)

	if hud.has_method("set_health"):
		hud.set_health(76, 100)
		var health_label = hud.get_node_or_null("MarginContainer/VBoxContainer/HealthLabel")
		runner.assert_true(health_label != null, "HUD should include a health label")
		if health_label != null:
			runner.assert_eq(health_label.text, "HP 76/100", "HUD should format player health")
	else:
		runner.assert_true(false, "HUD should expose set_health")

	var upgrade_feedback_label = hud.get_node_or_null("MarginContainer/VBoxContainer/UpgradeFeedbackLabel")
	runner.assert_true(upgrade_feedback_label != null, "HUD should include runtime upgrade feedback label")
	if hud.has_method("show_upgrade_feedback") and upgrade_feedback_label != null:
		runner.assert_true(not upgrade_feedback_label.visible, "upgrade feedback should start hidden")
		hud.show_upgrade_feedback("锋刃淬炼")
		runner.assert_true(upgrade_feedback_label.visible, "upgrade feedback should show after selecting an upgrade")
		runner.assert_eq(upgrade_feedback_label.text, "已选择：锋刃淬炼", "upgrade feedback should use Chinese copy")
		hud._process(2.0)
		runner.assert_true(not upgrade_feedback_label.visible, "upgrade feedback should hide after its timer expires")
	else:
		runner.assert_true(false, "HUD should expose show_upgrade_feedback")

	hud.queue_free()
