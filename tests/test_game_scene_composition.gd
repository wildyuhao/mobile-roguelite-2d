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

	game.free()
