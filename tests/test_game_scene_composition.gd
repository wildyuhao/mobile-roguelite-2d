extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/game/Game.tscn"):
		runner.assert_true(false, "game scene should exist")
		return

	var game_scene: PackedScene = load("res://scenes/game/Game.tscn")
	var game = game_scene.instantiate()
	runner.assert_true(game.has_node("Ground"), "game scene should include a ground sprite")
	runner.assert_true(game.has_node("PoolService"), "game scene should include a local pool service")
	runner.assert_true(game.has_node("CombatEffectPipeline"), "game scene should include a combat effect pipeline")
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
		runner.assert_true(
			player.get_node_or_null("HitFeedback") != null,
			"player should include layered hit feedback"
		)
		runner.assert_true(
			player.get_node_or_null("HitSpark") is Sprite2D,
			"player should include a hit spark sprite"
		)
		runner.assert_true(
			player.get_node_or_null("DamageLabel") is Label,
			"player should include a floating damage label"
		)
	var pipeline = game.get_node_or_null("CombatEffectPipeline")
	if pipeline != null:
		for scene_property in ["projectile_scene", "area_scene", "orbit_scene", "summon_scene"]:
			runner.assert_true(pipeline.get(scene_property) is PackedScene, "pipeline should configure %s" % scene_property)
	var game_loop_source := FileAccess.get_file_as_string("res://scripts/core/game_loop.gd")
	runner.assert_true(not game_loop_source.contains("weapon_type"), "game loop should not branch on weapon type")
	runner.assert_true(not game_loop_source.contains("_apply_pulse_event"), "game loop should not execute pulse damage")
	runner.assert_true(not game_loop_source.contains("_spawn_projectiles"), "game loop should not spawn weapon carriers")

	var enemy_scene: PackedScene = load("res://scenes/enemies/BasicDemon.tscn")
	var enemy = enemy_scene.instantiate()
	runner.assert_true(
		enemy.get_node_or_null("HitFeedback") != null,
		"basic enemy should include layered hit feedback"
	)
	runner.assert_true(
		enemy.get_node_or_null("HitSpark") is Sprite2D,
		"basic enemy should include a hit spark sprite"
	)
	runner.assert_true(
		enemy.get_node_or_null("StatusController") != null,
		"basic enemy should include a status controller"
	)
	enemy.free()

	for effect_path in [
		"res://art/effects/hit/player_contact_hit_burst.png",
		"res://art/effects/hit/enemy_weapon_hit_spark.png",
	]:
		runner.assert_true(
			ResourceLoader.exists(effect_path),
			"%s should exist" % effect_path
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
