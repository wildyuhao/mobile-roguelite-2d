extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/game/Game.tscn"):
		runner.assert_true(false, "game scene should exist")
		return

	var game_scene: PackedScene = load("res://scenes/game/Game.tscn")
	var game = game_scene.instantiate()
	runner.assert_true(game.has_node("Ground"), "game scene should include a ground sprite")
	runner.assert_true(game.has_node("VirtualJoystick/Stick"), "game scene should include a virtual joystick stick")
	runner.assert_true(game.has_node("SettlementPanel"), "game scene should include a settlement panel")

	var ground = game.get_node_or_null("Ground")
	if ground != null:
		runner.assert_true(ground.get("texture") != null, "ground sprite should have a texture")
	var enemy_director = game.get_node_or_null("EnemyDirector")
	if enemy_director != null:
		runner.assert_true(float(enemy_director.get("spawn_radius")) <= 360.0, "main scene enemy spawn radius should keep early monsters visible on mobile")
	var player = game.get_node_or_null("Player")
	runner.assert_true(player != null, "game should include the player")
	if player != null:
		runner.assert_true(
			player.get_node_or_null("AnimatedSprite2D") is AnimatedSprite2D,
			"player should use AnimatedSprite2D"
		)
		runner.assert_true(
			player.get_node_or_null("DirectionalAnimation") != null,
			"player should include directional animation control"
		)
	for strip_path in [
		"res://art/characters/player/animation/walk_front_strip.png",
		"res://art/characters/player/animation/walk_back_strip.png",
		"res://art/characters/player/animation/walk_side_strip.png",
	]:
		runner.assert_true(
			ResourceLoader.exists(strip_path),
			"%s should exist" % strip_path
		)

	game.free()
