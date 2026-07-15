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
	var idle_texture := sprite.sprite_frames.get_frame_texture("idle_front", 0) as AtlasTexture
	runner.assert_eq(
		idle_texture.region.position.x,
		128.0,
		"idle presentation should use the neutral second frame instead of a stride pose"
	)
	var idle_image := Image.create(2048, 128, false, Image.FORMAT_RGBA8)
	idle_image.fill(Color.WHITE)
	var idle_strip := ImageTexture.create_from_image(idle_image)
	runner.assert_true(
		controller.configure(sprite, strip, strip, strip, idle_strip),
		"directional animation should accept a dedicated front idle strip"
	)
	runner.assert_eq(
		sprite.sprite_frames.get_frame_count("idle_front"),
		16,
		"front idle should contain all sampled video frames"
	)
	runner.assert_near(
		sprite.sprite_frames.get_animation_speed("idle_front"),
		3.2,
		0.001,
		"front idle should retain the five-second source motion"
	)
	runner.assert_eq(
		sprite.sprite_frames.get_frame_count("idle_back"),
		1,
		"directions without a dedicated idle strip should retain a stable frame"
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
	runner.assert_eq(
		controller.update_motion(Vector2(0.70, 0.71)),
		&"walk_front",
		"near-diagonal input should initially retain the vertical walk"
	)
	runner.assert_eq(
		controller.update_motion(Vector2(0.71, 0.70)),
		&"walk_front",
		"minor joystick noise around a diagonal should not restart another direction"
	)
	runner.assert_eq(
		controller.update_motion(Vector2(0.95, 0.10)),
		&"walk_side",
		"decisive horizontal input should still switch to the side walk"
	)

	controller.free()
	sprite.free()
