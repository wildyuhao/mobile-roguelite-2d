extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/components/directional_animation.gd"):
		runner.assert_true(false, "directional animation component should exist")
		return
	var controller_script = load("res://scripts/components/directional_animation.gd")
	var controller = controller_script.new()
	var sprite := AnimatedSprite2D.new()
	var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var strip := ImageTexture.create_from_image(image)

	runner.assert_true(
		controller.configure(sprite, strip, strip, strip),
		"directional animation should configure valid strips"
	)
	runner.assert_true(
		sprite.sprite_frames.has_animation("walk_front"),
		"front walk animation should exist"
	)
	runner.assert_eq(
		sprite.sprite_frames.get_frame_count("walk_front"),
		6,
		"front walk should contain six frames"
	)
	runner.assert_eq(
		controller.update_motion(Vector2.RIGHT),
		&"walk_side",
		"right movement should use side walk"
	)
	runner.assert_true(not sprite.flip_h, "right movement should not mirror the side strip")
	runner.assert_eq(
		controller.update_motion(Vector2.LEFT),
		&"walk_side",
		"left movement should use side walk"
	)
	runner.assert_true(sprite.flip_h, "left movement should mirror the side strip")
	runner.assert_eq(
		controller.update_motion(Vector2.ZERO),
		&"idle_side",
		"stopping after horizontal movement should retain side facing"
	)
	runner.assert_true(sprite.flip_h, "stopping after left movement should retain mirroring")
	runner.assert_eq(
		controller.update_motion(Vector2.UP),
		&"walk_back",
		"up movement should use back walk"
	)
	runner.assert_eq(
		controller.update_motion(Vector2.ZERO),
		&"idle_back",
		"stopping should retain the last direction"
	)
	runner.assert_eq(
		controller.update_motion(Vector2.DOWN),
		&"walk_front",
		"down movement should use front walk"
	)

	controller.free()
	sprite.free()
