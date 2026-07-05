extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/ui/virtual_joystick.gd"):
		runner.assert_true(false, "virtual joystick script should exist")
		return

	var joystick_script = load("res://scripts/ui/virtual_joystick.gd")
	var joystick = joystick_script.new()
	joystick.size = Vector2(200, 200)

	if not joystick.has_method("begin_drag_local"):
		runner.assert_true(false, "virtual joystick should expose begin_drag_local")
		joystick.free()
		return

	runner.assert_true(joystick.begin_drag_local(Vector2(100, 100)), "drag should start inside joystick base")
	joystick.update_drag_local(Vector2(184, 100))
	runner.assert_near(joystick.move_vector.x, 1.0, 0.001, "right drag should produce positive x")
	runner.assert_near(joystick.move_vector.y, 0.0, 0.001, "horizontal drag should keep y near zero")

	joystick.update_drag_local(Vector2(400, 100))
	runner.assert_near(joystick.move_vector.length(), 1.0, 0.001, "joystick vector should clamp to unit length")

	joystick.end_drag()
	runner.assert_eq(joystick.move_vector, Vector2.ZERO, "joystick should reset after drag ends")
	runner.assert_true(not joystick.is_active, "joystick should mark itself inactive after drag ends")
	joystick.free()
