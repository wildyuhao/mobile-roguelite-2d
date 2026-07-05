extends RefCounted

class FakeSettlementPanel:
	extends Node

	var show_count: int = 0
	var last_title: String = ""
	var last_rewards: Dictionary = {}
	var last_summary: Dictionary = {}

	func show_result(title: String, rewards: Dictionary, summary: Dictionary) -> void:
		show_count += 1
		last_title = title
		last_rewards = rewards
		last_summary = summary

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/core/game_loop.gd"):
		runner.assert_true(false, "game loop script should exist")
		return

	var game_loop_script = load("res://scripts/core/game_loop.gd")
	var game_loop = game_loop_script.new()
	var victory_panel := FakeSettlementPanel.new()
	if game_loop.has_method("set_settlement_panel"):
		game_loop.set_settlement_panel(victory_panel)
	else:
		runner.assert_true(false, "game loop should accept a settlement panel")
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
		runner.assert_eq(victory_panel.last_title, "Boss Sealed", "boss defeat should show victory title")
	else:
		runner.assert_true(false, "game loop should record enemy defeat summaries")

	var defeat_loop = game_loop_script.new()
	var defeat_panel := FakeSettlementPanel.new()
	if defeat_loop.has_method("set_settlement_panel"):
		defeat_loop.set_settlement_panel(defeat_panel)
	else:
		runner.assert_true(false, "game loop should accept a settlement panel for defeat")
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
		runner.assert_eq(defeat_panel.last_title, "Run Failed", "player defeat should show defeat title")
	else:
		runner.assert_true(false, "game loop should record player defeat")
	defeat_panel.free()
	defeat_loop.free()

	victory_panel.free()
	game_loop.free()
