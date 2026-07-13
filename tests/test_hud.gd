extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/HUD.tscn"):
		runner.assert_true(false, "HUD scene should exist")
		return

	var hud_scene: PackedScene = load("res://scenes/ui/HUD.tscn")
	var hud = hud_scene.instantiate()
	Engine.get_main_loop().root.add_child(hud)

	var timer_label = hud.get_node_or_null("MarginContainer/VBoxContainer/TopRow/TimerLabel")
	var level_label = hud.get_node_or_null("MarginContainer/VBoxContainer/TopRow/LevelLabel")
	var health_bar = hud.get_node_or_null("MarginContainer/VBoxContainer/HealthBar")
	var health_label = hud.get_node_or_null("MarginContainer/VBoxContainer/HealthBar/HealthLabel")
	var experience_bar = hud.get_node_or_null("MarginContainer/VBoxContainer/ExperienceBar")
	var experience_label = hud.get_node_or_null("MarginContainer/VBoxContainer/ExperienceBar/ExperienceLabel")
	runner.assert_true(timer_label is Label, "HUD should include a combat timer")
	runner.assert_true(level_label is Label, "HUD should include a level label")
	runner.assert_true(health_bar is ProgressBar, "HUD should include a health progress bar")
	runner.assert_true(health_label is Label, "health bar should include a numeric label")
	runner.assert_true(experience_bar is ProgressBar, "HUD should include an experience progress bar")
	runner.assert_true(experience_label is Label, "experience bar should include a numeric label")
	if timer_label is Label and level_label is Label:
		hud.set_run_time(125.0)
		hud.set_level(4)
		runner.assert_eq(timer_label.text, "02:05", "HUD should format combat time")
		runner.assert_eq(level_label.text, "等级 4", "HUD level should use Chinese copy")
	if experience_bar is ProgressBar and experience_label is Label:
		hud.set_experience(3, 8)
		runner.assert_eq(experience_bar.max_value, 8.0, "experience bar should track required experience")
		runner.assert_eq(experience_bar.value, 3.0, "experience bar should track current experience")
		runner.assert_eq(experience_label.text, "灵气 3 / 8", "experience text should use Chinese copy")
		runner.assert_true(experience_bar.custom_minimum_size.y >= 26.0, "experience bar should be readable on mobile")
		hud.set_experience(12, 8)
		runner.assert_eq(experience_bar.value, 8.0, "experience bar should clamp overflow")
		runner.assert_eq(experience_label.text, "灵气 8 / 8", "experience text should match clamped progress")
		hud.set_experience(-3, 0)
		runner.assert_eq(experience_bar.max_value, 1.0, "experience bar should sanitize invalid requirements")
		runner.assert_eq(experience_bar.value, 0.0, "experience bar should clamp negative progress")
		runner.assert_eq(experience_label.text, "灵气 0 / 1", "experience text should match sanitized progress")

	if hud.has_method("set_health"):
		hud.set_health(76, 100)
		if health_bar is ProgressBar and health_label is Label:
			runner.assert_eq(health_bar.max_value, 100.0, "health bar should track maximum health")
			runner.assert_eq(health_bar.value, 76.0, "health bar should track current health")
			runner.assert_eq(health_label.text, "生命 76 / 100", "HUD health should use Chinese copy")
			runner.assert_true(health_bar.custom_minimum_size.x >= 360.0, "health bar should have stable mobile width")
			runner.assert_true(health_bar.custom_minimum_size.y >= 30.0, "health bar should be readable on mobile")
			hud.set_health(120, 100)
			runner.assert_eq(health_bar.value, 100.0, "health bar should clamp overheal")
			runner.assert_eq(health_label.text, "生命 100 / 100", "health text should match clamped progress")
			hud.set_health(-5, 0)
			runner.assert_eq(health_bar.max_value, 1.0, "health bar should sanitize invalid maximum")
			runner.assert_eq(health_bar.value, 0.0, "health bar should clamp negative health")
			runner.assert_eq(health_label.text, "生命 0 / 1", "health text should match sanitized health")
			hud.set_health(76, 100)
	else:
		runner.assert_true(false, "HUD should expose set_health")

	var upgrade_feedback_label = hud.get_node_or_null("MarginContainer/VBoxContainer/UpgradeFeedbackLabel")
	runner.assert_true(upgrade_feedback_label != null, "HUD should include runtime upgrade feedback label")
	if hud.has_method("show_upgrade_feedback") and upgrade_feedback_label != null:
		runner.assert_true(not upgrade_feedback_label.visible, "upgrade feedback should start hidden")
		hud.show_upgrade_feedback("锋刃淬炼")
		runner.assert_true(upgrade_feedback_label.visible, "upgrade feedback should show after selecting an upgrade")
		runner.assert_eq(upgrade_feedback_label.text, "已选择：锋刃淬炼", "upgrade feedback should use Chinese copy")
		runner.assert_true(upgrade_feedback_label.clip_text, "upgrade feedback should not widen the HUD")
		runner.assert_true(upgrade_feedback_label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING, "upgrade feedback should trim long names")
		hud._process(2.0)
		runner.assert_true(not upgrade_feedback_label.visible, "upgrade feedback should hide after its timer expires")
	else:
		runner.assert_true(false, "HUD should expose show_upgrade_feedback")

	if hud.has_method("show_damage_feedback") and health_label is Label and health_bar is ProgressBar:
		var base_scale: Vector2 = health_label.scale
		var base_color: Color = health_label.modulate
		var base_bar_scale: Vector2 = health_bar.scale
		var base_bar_color: Color = health_bar.modulate
		hud.show_damage_feedback(8)
		runner.assert_true(
			health_label.scale.x > base_scale.x,
			"damage feedback should punch the health label"
		)
		runner.assert_true(
			health_label.modulate.r > health_label.modulate.g,
			"damage feedback should tint the health label red"
		)
		runner.assert_true(
			health_bar.scale.x > base_bar_scale.x,
			"damage feedback should punch the health bar"
		)
		runner.assert_true(
			health_bar.modulate != base_bar_color,
			"damage feedback should tint the health bar"
		)
		hud._process(0.3)
		runner.assert_eq(
			health_label.scale,
			base_scale,
			"damage feedback should restore the health label scale"
		)
		runner.assert_eq(
			health_label.modulate,
			base_color,
			"damage feedback should restore the health label tint"
		)
		runner.assert_eq(health_bar.scale, base_bar_scale, "damage feedback should restore health bar scale")
		runner.assert_eq(health_bar.modulate, base_bar_color, "damage feedback should restore health bar tint")
	else:
		runner.assert_true(false, "HUD should expose show_damage_feedback")

	var margin = hud.get_node_or_null("MarginContainer")
	if margin is Control:
		runner.assert_eq(margin.anchor_left, 0.0, "HUD should anchor to the left edge")
		runner.assert_eq(margin.anchor_top, 0.0, "HUD should anchor to the top edge")
		runner.assert_true(margin.offset_left >= 24.0, "HUD should keep a left safe margin")
		runner.assert_true(margin.offset_top >= 24.0, "HUD should keep a top safe margin")
		var pause_scene: PackedScene = load("res://scenes/ui/PauseOverlay.tscn")
		var pause_overlay = pause_scene.instantiate()
		var pause_button = pause_overlay.get_node_or_null("PauseButton")
		if pause_button is Control:
			var pause_left_at_design_width: float = 720.0 + float(pause_button.offset_left)
			runner.assert_true(
				margin.offset_right <= pause_left_at_design_width,
				"HUD should not enter the pause button touch region"
			)
		pause_overlay.free()

	hud.queue_free()
