extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/player/player_controller.gd"):
		runner.assert_true(false, "player controller script should exist")
		return

	var player_script = load("res://scripts/player/player_controller.gd")
	var player = player_script.new()

	if player.has_method("set_external_move_vector"):
		player.set_external_move_vector(Vector2(3, 4))
		runner.assert_near(player.external_move_vector.length(), 1.0, 0.001, "external movement vector should clamp")
		runner.assert_eq(player._get_move_input(), player.external_move_vector, "external joystick input should drive movement")
	else:
		runner.assert_true(false, "player should accept an external move vector")

	player.free()
