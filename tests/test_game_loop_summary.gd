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

	var defeat_loop = game_loop_script.new()
	defeat_loop.run_summary = {
		"defeated_enemies": 3,
		"base_materials": 7,
		"boss_defeated": false,
	}
	if defeat_loop.has_method("record_player_defeat"):
		var defeat_summary = defeat_loop.record_player_defeat()
		runner.assert_eq(defeat_summary["boss_defeated"], false, "player defeat should not mark boss defeated")
		runner.assert_eq(defeat_loop.run_ended, true, "player defeat should end the run")
		runner.assert_eq(defeat_loop.settlement_rewards["materials"], 10, "player defeat should calculate settlement rewards")
	else:
		runner.assert_true(false, "game loop should record player defeat")
	defeat_loop.free()

	game_loop.free()
