extends RefCounted

class FakeSettlementPanel:
	extends Node

	signal restart_requested
	signal upgrade_requested(equipment_id: String)

	var show_count: int = 0
	var last_title: String = ""
	var last_rewards: Dictionary = {}
	var last_summary: Dictionary = {}
	var last_upgrade_offer: Dictionary = {}
	var last_upgrade_offers: Array = []

	func show_result(title: String, rewards: Dictionary, summary: Dictionary) -> void:
		show_count += 1
		last_title = title
		last_rewards = rewards
		last_summary = summary

	func show_upgrade_offer(equipment_id: String, display_name: String, level: int, cost: int, total_materials: int, can_upgrade: bool) -> void:
		last_upgrade_offer = {
			"equipment_id": equipment_id,
			"display_name": display_name,
			"level": level,
			"cost": cost,
			"total_materials": total_materials,
			"can_upgrade": can_upgrade,
		}

	func show_upgrade_offers(offers: Array) -> void:
		last_upgrade_offers = offers.duplicate(true)

class FakePlayer:
	extends Node2D

	var last_modifiers: Dictionary = {}

	func apply_stat_modifiers(modifiers: Dictionary) -> void:
		last_modifiers = modifiers.duplicate(true)

class FakeWeaponSystem:
	extends Node

	var last_modifiers: Dictionary = {}

	func set_stat_modifiers(modifiers: Dictionary) -> void:
		last_modifiers = modifiers.duplicate(true)

class FakeSaveSystem:
	extends RefCounted

	var data: Dictionary = {}
	var save_calls: int = 0
	var last_saved_data: Dictionary = {}

	func _init(starting_materials: int = 0) -> void:
		data = {
			"version": 1,
			"materials": starting_materials,
			"equipment_levels": {},
			"unlocked_equipment": ["talisman_robe", "cloudstep_boots", "bronze_gear_core", "sword_gourd"],
			"settings": {},
		}

	func load_game() -> Dictionary:
		return data.duplicate(true)

	func save_game(new_data: Dictionary) -> bool:
		save_calls += 1
		last_saved_data = new_data.duplicate(true)
		data = new_data.duplicate(true)
		return true

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/core/game_loop.gd"):
		runner.assert_true(false, "game loop script should exist")
		return

	var game_loop_script = load("res://scripts/core/game_loop.gd")
	var game_loop = game_loop_script.new()
	var victory_panel := FakeSettlementPanel.new()
	var victory_save := FakeSaveSystem.new(11)
	if game_loop.has_method("set_settlement_panel"):
		game_loop.set_settlement_panel(victory_panel)
	else:
		runner.assert_true(false, "game loop should accept a settlement panel")
	if game_loop.has_method("set_save_system"):
		game_loop.set_save_system(victory_save)
	else:
		runner.assert_true(false, "game loop should accept an injected save system")
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
		runner.assert_eq(victory_save.save_calls, 1, "boss defeat should save rewards once")
		runner.assert_eq(int(victory_save.last_saved_data.get("materials", -1)), 80, "boss rewards should be added to saved materials")
		runner.assert_eq(victory_panel.last_upgrade_offer.get("equipment_id", ""), "talisman_robe", "settlement should show robe upgrade offer")
		runner.assert_eq(victory_panel.last_upgrade_offers.size(), 3, "settlement should show three equipment upgrade offers")
		var second_offer_id := ""
		if victory_panel.last_upgrade_offers.size() > 1:
			second_offer_id = victory_panel.last_upgrade_offers[1].get("equipment_id", "")
		runner.assert_eq(second_offer_id, "cloudstep_boots", "second settlement offer should upgrade boots")
		runner.assert_eq(int(victory_panel.last_upgrade_offer.get("total_materials", -1)), 80, "settlement upgrade offer should show saved materials after rewards")
		runner.assert_true(bool(victory_panel.last_upgrade_offer.get("can_upgrade", false)), "settlement upgrade offer should be affordable after rewards")
		victory_panel.upgrade_requested.emit("cloudstep_boots")
		runner.assert_eq(victory_save.save_calls, 2, "upgrade request should save upgraded equipment")
		runner.assert_eq(victory_save.last_saved_data["materials"], 70, "upgrade request should spend materials")
		runner.assert_eq(int(victory_save.last_saved_data.get("equipment_levels", {}).get("cloudstep_boots", -1)), 2, "upgrade request should increase boot level")
		var refreshed_boot_level := -1
		if victory_panel.last_upgrade_offers.size() > 1:
			refreshed_boot_level = int(victory_panel.last_upgrade_offers[1]["level"])
		runner.assert_eq(refreshed_boot_level, 2, "upgrade request should refresh shown boot level")
		game_loop.record_enemy_defeat({
			"enemy_position": Vector2.ZERO,
			"experience_value": 5,
			"material_value": 999,
			"is_boss": false,
		})
		runner.assert_eq(victory_save.save_calls, 2, "late defeats after run end should not resave rewards")
		runner.assert_eq(game_loop.run_summary["defeated_enemies"], 1, "late defeats after run end should not change the summary")
	else:
		runner.assert_true(false, "game loop should record enemy defeat summaries")

	var defeat_loop = game_loop_script.new()
	var defeat_panel := FakeSettlementPanel.new()
	var defeat_save := FakeSaveSystem.new(5)
	if defeat_loop.has_method("set_settlement_panel"):
		defeat_loop.set_settlement_panel(defeat_panel)
	else:
		runner.assert_true(false, "game loop should accept a settlement panel for defeat")
	if defeat_loop.has_method("set_save_system"):
		defeat_loop.set_save_system(defeat_save)
	else:
		runner.assert_true(false, "game loop should accept an injected save system for defeat")
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
		runner.assert_eq(defeat_save.save_calls, 1, "player defeat should save rewards once")
		runner.assert_eq(int(defeat_save.last_saved_data.get("materials", -1)), 15, "defeat rewards should be added to saved materials")
		defeat_loop.record_player_defeat()
		runner.assert_eq(defeat_save.save_calls, 1, "repeated player defeat should not resave rewards")
	else:
		runner.assert_true(false, "game loop should record player defeat")
	defeat_panel.free()
	defeat_loop.free()

	var equipment_loop = game_loop_script.new()
	var equipment_player := FakePlayer.new()
	var equipment_weapon_system := FakeWeaponSystem.new()
	equipment_loop.player = equipment_player
	equipment_loop.weapon_system = equipment_weapon_system
	runner.assert_true(equipment_loop.database.load_all(), "database should load before applying saved equipment")
	if equipment_loop.has_method("apply_saved_equipment_to_player"):
		equipment_loop.apply_saved_equipment_to_player({
			"unlocked_equipment": ["talisman_robe", "cloudstep_boots", "bronze_gear_core"],
			"equipment_levels": {
				"talisman_robe": 3,
				"cloudstep_boots": 2,
				"bronze_gear_core": 2,
			},
		})
		runner.assert_eq(equipment_player.last_modifiers["max_health"], 30, "saved robe level should apply health to the player")
		runner.assert_eq(equipment_player.last_modifiers["move_speed"], 36, "saved boot level should apply speed to the player")
		runner.assert_near(float(equipment_weapon_system.last_modifiers.get("weapon_cooldown_multiplier", 0.0)), -0.1, 0.001, "saved gear core level should apply cooldown to weapons")
	else:
		runner.assert_true(false, "game loop should apply saved equipment to the player")
	equipment_player.free()
	equipment_weapon_system.free()
	equipment_loop.free()

	victory_panel.free()
	game_loop.free()
