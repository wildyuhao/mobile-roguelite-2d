extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/core/game_loop.gd"):
		runner.assert_true(false, "game loop script should exist")
		return

	var game_loop_script = load("res://scripts/core/game_loop.gd")
	var game_loop = game_loop_script.new()
	var payload := {
		"enemy_position": Vector2.ZERO,
		"experience_value": 30,
		"material_value": 50,
		"is_boss": true,
	}

	if game_loop.has_method("record_enemy_defeat"):
		var summary = game_loop.record_enemy_defeat(payload)
		runner.assert_eq(summary["defeated_enemies"], 1, "game loop should count defeated enemies")
		runner.assert_eq(summary["base_materials"], 50, "game loop should add material drops")
		runner.assert_eq(summary["boss_defeated"], true, "game loop should mark boss defeated")
		runner.assert_eq(game_loop.run_ended, true, "boss defeat should end the run")
		runner.assert_eq(game_loop.settlement_rewards["materials"], 69, "boss defeat should calculate settlement rewards")
	else:
		runner.assert_true(false, "game loop should record enemy defeat summaries")

	game_loop.free()
