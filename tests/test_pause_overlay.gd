extends RefCounted

class FakePauseOverlay:
	extends Node

	signal pause_requested
	signal resume_requested
	signal restart_requested

	var pause_visible: bool = false
	var pause_available: bool = true
	var hide_calls: int = 0

	func show_pause() -> void:
		pause_visible = true

	func hide_pause() -> void:
		pause_visible = false
		hide_calls += 1

	func set_pause_available(available: bool) -> void:
		pause_available = available
		if not available:
			pause_visible = false

class FakeJoystick:
	extends Node

	var end_drag_calls: int = 0

	func end_drag() -> void:
		end_drag_calls += 1

class FakeMovablePlayer:
	extends Node2D

	var last_move_vector := Vector2.INF

	func set_external_move_vector(move_vector: Vector2) -> void:
		last_move_vector = move_vector

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/PauseOverlay.tscn"):
		runner.assert_true(false, "pause overlay scene should exist")
		return

	var overlay_scene: PackedScene = load("res://scenes/ui/PauseOverlay.tscn")
	var overlay = overlay_scene.instantiate()
	Engine.get_main_loop().root.add_child(overlay)

	runner.assert_eq(
		overlay.process_mode,
		Node.PROCESS_MODE_ALWAYS,
		"pause overlay should keep processing while the tree is paused"
	)
	var pause_button = overlay.get_node_or_null("PauseButton")
	var pause_screen = overlay.get_node_or_null("PauseScreen")
	var resume_button = overlay.get_node_or_null("PauseScreen/PanelContainer/VBoxContainer/ResumeButton")
	var restart_button = overlay.get_node_or_null("PauseScreen/PanelContainer/VBoxContainer/RestartButton")
	runner.assert_true(pause_button is TextureButton, "pause overlay should expose an icon button")
	runner.assert_true(pause_screen is Control, "pause overlay should include a full-screen pause layer")
	runner.assert_true(resume_button is Button, "pause overlay should include a resume command")
	runner.assert_true(restart_button is Button, "pause overlay should include a restart command")
	if pause_button is TextureButton:
		runner.assert_true(pause_button.texture_normal is Texture2D, "pause button should bind formal icon art")
		runner.assert_true(pause_button.custom_minimum_size.x >= 56.0, "pause button should have a mobile touch target")
		runner.assert_eq(pause_button.anchor_left, 1.0, "pause button should anchor to the right edge")
		runner.assert_eq(pause_button.anchor_right, 1.0, "pause button should stay right-aligned on wide screens")
	if pause_screen is Control:
		runner.assert_eq(pause_screen.anchor_right, 1.0, "pause shade should fill expanded viewport width")
		runner.assert_eq(pause_screen.anchor_bottom, 1.0, "pause shade should fill expanded viewport height")
		var panel = pause_screen.get_node_or_null("PanelContainer")
		if panel is Control:
			runner.assert_eq(panel.anchor_left, 0.5, "pause panel should stay horizontally centered")
			runner.assert_eq(panel.anchor_top, 0.5, "pause panel should stay vertically centered")
	if resume_button is Button:
		runner.assert_true(resume_button.icon is Texture2D, "resume button should bind a play icon")
		runner.assert_true(resume_button.expand_icon, "resume button should scale its source icon")
		runner.assert_true(resume_button.custom_minimum_size.y >= 64.0, "resume should have a mobile touch target")
	if restart_button is Button:
		runner.assert_true(restart_button.icon is Texture2D, "restart button should bind a restart icon")
		runner.assert_true(restart_button.expand_icon, "restart button should scale its source icon")
		runner.assert_true(restart_button.custom_minimum_size.y >= 64.0, "restart should have a mobile touch target")

	var pause_requests := [0]
	var resume_requests := [0]
	var restart_requests := [0]
	overlay.pause_requested.connect(func() -> void: pause_requests[0] += 1)
	overlay.resume_requested.connect(func() -> void: resume_requests[0] += 1)
	overlay.restart_requested.connect(func() -> void: restart_requests[0] += 1)
	pause_button.emit_signal("pressed")
	runner.assert_eq(pause_requests[0], 1, "pause icon should emit one pause request")
	overlay.show_pause()
	runner.assert_true(pause_screen.visible, "show_pause should reveal the pause layer")
	runner.assert_true(not pause_button.visible, "show_pause should hide the corner icon")
	overlay.set_pause_available(false)
	runner.assert_true(not pause_screen.visible, "disabling pause should close an existing manual pause layer")
	overlay.set_pause_available(true)
	overlay.show_pause()
	resume_button.emit_signal("pressed")
	restart_button.emit_signal("pressed")
	runner.assert_eq(resume_requests[0], 1, "resume command should emit once")
	runner.assert_eq(restart_requests[0], 1, "restart command should emit once")
	overlay.hide_pause()
	runner.assert_true(not pause_screen.visible, "hide_pause should conceal the pause layer")
	runner.assert_true(pause_button.visible, "hide_pause should restore the corner icon")
	overlay.set_pause_available(false)
	runner.assert_true(not pause_button.visible, "unavailable pause should hide the corner icon")

	overlay.queue_free()

	var game_loop_script = load("res://scripts/core/game_loop.gd")
	var game_loop = game_loop_script.new()
	var fake_overlay := FakePauseOverlay.new()
	var fake_joystick := FakeJoystick.new()
	var fake_player := FakeMovablePlayer.new()
	game_loop.set_pause_overlay(fake_overlay)
	game_loop.virtual_joystick = fake_joystick
	game_loop.player = fake_player
	game_loop.manual_pause_active = true
	fake_overlay.show_pause()
	game_loop._prepare_automatic_pause()
	runner.assert_true(not game_loop.manual_pause_active, "automatic pause should take ownership from manual pause")
	runner.assert_true(not fake_overlay.pause_visible, "automatic pause should close the manual pause layer")
	runner.assert_true(not fake_overlay.pause_available, "automatic pause should disable the corner entry")
	runner.assert_eq(fake_joystick.end_drag_calls, 1, "automatic pause should end the active joystick drag")
	runner.assert_eq(fake_player.last_move_vector, Vector2.ZERO, "automatic pause should clear player movement")
	game_loop._begin_terminal_pause_state()
	runner.assert_true(game_loop.terminal_pause_active, "terminal flow should record pause ownership")
	runner.assert_true(not fake_overlay.pause_available, "terminal flow should keep manual pause disabled")
	var replacement_overlay := FakePauseOverlay.new()
	game_loop.set_pause_overlay(replacement_overlay)
	runner.assert_true(
		not fake_overlay.pause_requested.is_connected(Callable(game_loop, "_on_manual_pause_requested")),
		"replacing pause overlay should disconnect the prior pause signal"
	)
	game_loop.free()
	fake_overlay.free()
	replacement_overlay.free()
	fake_joystick.free()
	fake_player.free()
