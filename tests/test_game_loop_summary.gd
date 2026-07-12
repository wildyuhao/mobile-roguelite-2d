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
	var last_upgrade_feedback: String = ""

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

	func show_upgrade_feedback(display_name: String, level: int) -> void:
		last_upgrade_feedback = "已强化：%s %d级" % [display_name, level]

class FakePlayer:
	extends Node2D

	var last_modifiers: Dictionary = {}

	func apply_stat_modifiers(modifiers: Dictionary) -> void:
		last_modifiers = modifiers.duplicate(true)

class FakeHealth:
	extends Node

	var current_health: int = 46
	var max_health: int = 110

class FakeWeaponSystem:
	extends Node

	var last_modifiers: Dictionary = {}

	func set_stat_modifiers(modifiers: Dictionary) -> void:
		last_modifiers = modifiers.duplicate(true)

class FakeHUD:
	extends Node

	var last_upgrade_feedback: String = ""
	var last_health := Vector2i(-1, -1)

	func show_upgrade_feedback(display_name: String) -> void:
		last_upgrade_feedback = display_name

	func set_health(current: int, maximum: int) -> void:
		last_health = Vector2i(current, maximum)

class FakeEnemyDirector:
	extends Node

	var heavy_damage_calls: int = 0

	func notify_player_heavy_damage() -> void:
		heavy_damage_calls += 1

class FakePoolService:
	extends Node

	var acquired_keys: Array[String] = []
	var cached_nodes: Dictionary = {}

	func acquire(pool_key: String, scene: PackedScene, parent: Node) -> Node:
		acquired_keys.append(pool_key)
		var node: Node = cached_nodes.get(pool_key)
		if node == null:
			node = scene.instantiate()
			parent.add_child(node)
			cached_nodes[pool_key] = node
		if node.has_method("activate_from_pool"):
			node.activate_from_pool()
		return node

class FakeExperienceSystem:
	extends Node

	var total: int = 0

	func add_experience(amount: int) -> void:
		total += amount

class FakePickup:
	extends Node

	var last_bonus: float = -1.0

	func set_collection_radius_bonus(bonus: float) -> void:
		last_bonus = bonus

class FakeExperiencePickup:
	extends Node2D

	signal collected(amount: int)

	var configured_value: int = 0
	var last_bonus: float = -1.0

	func configure(value: int) -> void:
		configured_value = value

	func set_collection_radius_bonus(bonus: float) -> void:
		last_bonus = bonus

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
			"unlocked_equipment": ["talisman_robe", "cloudstep_boots", "bronze_gear_core", "jade_compass", "sword_gourd"],
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
		runner.assert_eq(victory_panel.last_title, "封印成功", "boss defeat should show victory title")
		runner.assert_eq(victory_save.save_calls, 1, "boss defeat should save rewards once")
		runner.assert_eq(int(victory_save.last_saved_data.get("materials", -1)), 80, "boss rewards should be added to saved materials")
		runner.assert_eq(victory_panel.last_upgrade_offer.get("equipment_id", ""), "talisman_robe", "settlement should show robe upgrade offer")
		runner.assert_eq(victory_panel.last_upgrade_offer.get("display_name", ""), "符甲法袍", "settlement should show Chinese equipment names")
		runner.assert_eq(victory_panel.last_upgrade_offers.size(), 4, "settlement should show four equipment upgrade offers")
		var second_offer_id := ""
		if victory_panel.last_upgrade_offers.size() > 1:
			second_offer_id = victory_panel.last_upgrade_offers[1].get("equipment_id", "")
		runner.assert_eq(second_offer_id, "cloudstep_boots", "second settlement offer should upgrade boots")
		var fourth_offer_id := ""
		if victory_panel.last_upgrade_offers.size() > 3:
			fourth_offer_id = victory_panel.last_upgrade_offers[3].get("equipment_id", "")
		runner.assert_eq(fourth_offer_id, "jade_compass", "fourth settlement offer should upgrade compass")
		runner.assert_eq(victory_panel.last_upgrade_offers[0].get("stat_summary", ""), "生命 +10", "robe offer should describe health gain")
		runner.assert_eq(victory_panel.last_upgrade_offers[1].get("stat_summary", ""), "移速 +18", "boot offer should describe speed gain")
		runner.assert_eq(victory_panel.last_upgrade_offers[2].get("stat_summary", ""), "冷却 -5%", "gear core offer should describe cooldown gain")
		runner.assert_eq(victory_panel.last_upgrade_offers[3].get("stat_summary", ""), "拾取 +24，灵石 +10%", "compass offer should describe pickup and material gain")
		runner.assert_eq(victory_panel.last_upgrade_offers[0].get("route_label", ""), "生命", "robe offer should include a route tag")
		runner.assert_eq(victory_panel.last_upgrade_offers[1].get("route_label", ""), "移速", "boot offer should include a route tag")
		runner.assert_eq(victory_panel.last_upgrade_offers[2].get("route_label", ""), "冷却", "gear core offer should include a route tag")
		runner.assert_eq(victory_panel.last_upgrade_offers[3].get("route_label", ""), "聚灵", "compass offer should include a route tag")
		runner.assert_true(String(victory_panel.last_upgrade_offers[0].get("route_color", "")).begins_with("#"), "robe offer should include a route color")
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
		runner.assert_eq(victory_panel.last_upgrade_feedback, "已强化：踏云靴 2级", "upgrade request should show success feedback")
		victory_panel.upgrade_requested.emit("jade_compass")
		runner.assert_eq(int(victory_save.last_saved_data.get("equipment_levels", {}).get("jade_compass", -1)), 2, "upgrade request should increase compass level")
		game_loop.record_enemy_defeat({
			"enemy_position": Vector2.ZERO,
			"experience_value": 5,
			"material_value": 999,
			"is_boss": false,
		})
		runner.assert_eq(victory_save.save_calls, 3, "late defeats after run end should not resave rewards")
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
		runner.assert_eq(defeat_panel.last_title, "挑战失败", "player defeat should show defeat title")
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

	var gain_loop = game_loop_script.new()
	var gain_panel := FakeSettlementPanel.new()
	var gain_save := FakeSaveSystem.new(0)
	if gain_loop.has_method("set_settlement_panel"):
		gain_loop.set_settlement_panel(gain_panel)
	if gain_loop.has_method("set_save_system"):
		gain_loop.set_save_system(gain_save)
	runner.assert_true(gain_loop.database.load_all(), "database should load before testing material gain")
	gain_loop.apply_saved_equipment_to_player({
		"unlocked_equipment": ["jade_compass"],
		"equipment_levels": {
			"jade_compass": 2,
		},
	})
	gain_loop.record_enemy_defeat({
		"enemy_position": Vector2.ZERO,
		"experience_value": 0,
		"material_value": 50,
		"is_boss": true,
	})
	runner.assert_eq(gain_loop.settlement_rewards["materials"], 83, "saved material gain should boost settlement rewards")
	runner.assert_eq(gain_save.last_saved_data["materials"], 83, "boosted settlement rewards should be saved")
	gain_panel.free()
	gain_loop.free()

	var stat_loop = game_loop_script.new()
	var stat_player := FakePlayer.new()
	var stat_health := FakeHealth.new()
	stat_health.name = "HealthComponent"
	stat_player.add_child(stat_health)
	var stat_weapon_system := FakeWeaponSystem.new()
	var stat_hud := FakeHUD.new()
	stat_loop.player = stat_player
	stat_loop.weapon_system = stat_weapon_system
	stat_loop.hud = stat_hud
	runner.assert_true(stat_loop.database.load_all(), "database should load before applying runtime stat upgrades")
	stat_loop.upgrade_system.configure(stat_loop.database.get_upgrades())
	stat_loop.runtime_state["upgrade_stacks"] = {
		"pickup_radius_1": 2,
		"weapon_damage_1": 1,
	}
	stat_loop.apply_saved_equipment_to_player({
		"unlocked_equipment": [],
		"equipment_levels": {},
	})
	runner.assert_eq(
		stat_hud.last_health,
		Vector2i(46, 110),
		"runtime stat application should immediately refresh HUD health"
	)
	runner.assert_eq(stat_player.last_modifiers.get("pickup_radius", 0), 48, "runtime pickup radius should be included in player modifiers")
	runner.assert_near(float(stat_weapon_system.last_modifiers.get("weapon_damage_multiplier", 0.0)), 0.15, 0.001, "runtime damage should be included in weapon modifiers")
	var fake_pickup := FakePickup.new()
	if stat_loop.has_method("configure_pickup_collection_radius"):
		stat_loop.configure_pickup_collection_radius(fake_pickup)
		runner.assert_near(fake_pickup.last_bonus, 48.0, 0.001, "game loop should pass pickup radius to spawned pickups")
	else:
		runner.assert_true(false, "game loop should configure pickup collection radius")
	if stat_loop.has_method("_spawn_experience_pickup"):
		var fake_pickup_scene := PackedScene.new()
		var fake_pickup_source := FakeExperiencePickup.new()
		runner.assert_eq(fake_pickup_scene.pack(fake_pickup_source), OK, "fake pickup scene should pack for game loop spawn test")
		fake_pickup_source.free()
		stat_loop.experience_pickup_scene = fake_pickup_scene
		stat_loop._spawn_experience_pickup(Vector2(12, 34), 7)
		var spawned_pickup = stat_loop.get_child(stat_loop.get_child_count() - 1)
		runner.assert_true(spawned_pickup is FakeExperiencePickup, "game loop should spawn an experience pickup instance")
		if spawned_pickup is FakeExperiencePickup:
			runner.assert_eq(spawned_pickup.configured_value, 7, "spawned pickup should receive experience value")
			runner.assert_eq(spawned_pickup.global_position, Vector2(12, 34), "spawned pickup should appear at enemy position")
			runner.assert_near(spawned_pickup.last_bonus, 48.0, 0.001, "spawned pickup should receive pickup radius bonus")
	else:
		runner.assert_true(false, "game loop should expose safe experience pickup spawn helper")
	if stat_loop.has_method("_show_runtime_upgrade_feedback"):
		stat_loop._show_runtime_upgrade_feedback({
			"id": "weapon_damage_1",
			"display_name": "Sharpened Edge",
		})
		runner.assert_eq(stat_hud.last_upgrade_feedback, "Sharpened Edge", "runtime upgrade selection should show HUD feedback")
	else:
		runner.assert_true(false, "game loop should expose runtime upgrade feedback helper")
	fake_pickup.free()
	stat_hud.free()
	stat_player.free()
	stat_weapon_system.free()
	stat_loop.free()

	var pressure_loop = game_loop_script.new()
	var pressure_player := Node2D.new()
	var pressure_health = load("res://scripts/components/health_component.gd").new()
	var pressure_director := FakeEnemyDirector.new()
	pressure_health.name = "HealthComponent"
	pressure_player.add_child(pressure_health)
	pressure_health.configure(100)
	pressure_loop.player = pressure_player
	pressure_loop.enemy_director = pressure_director
	if pressure_loop.has_method("_on_player_damaged"):
		pressure_loop._on_player_damaged(24)
		runner.assert_eq(
			pressure_director.heavy_damage_calls,
			0,
			"small hit should not suppress pressure"
		)
		pressure_loop._on_player_damaged(25)
		runner.assert_eq(
			pressure_director.heavy_damage_calls,
			1,
			"quarter-health hit should suppress pressure"
		)
	else:
		runner.assert_true(false, "game loop should forward heavy damage to pressure")
	pressure_director.free()
	pressure_player.free()
	pressure_loop.free()

	var projectile_pool_loop = game_loop_script.new()
	var projectile_pool := FakePoolService.new()
	if (
		projectile_pool_loop.has_method("set_pool_service")
		and projectile_pool_loop.has_method("_acquire_runtime_node")
	):
		projectile_pool_loop.set_pool_service(projectile_pool)
		var pooled_projectile = projectile_pool_loop._acquire_runtime_node(
			"projectile",
			load("res://scenes/weapons/Projectile.tscn")
		)
		runner.assert_true(
			pooled_projectile != null,
			"game loop should acquire a projectile node"
		)
		runner.assert_eq(
			projectile_pool.acquired_keys,
			["projectile"],
			"game loop should request the projectile pool"
		)
	else:
		runner.assert_true(false, "game loop should expose pooled runtime acquisition")
	projectile_pool.free()
	projectile_pool_loop.free()

	var pickup_pool_loop = game_loop_script.new()
	var pickup_pool = load("res://scripts/systems/pool_service.gd").new()
	var pickup_experience := FakeExperienceSystem.new()
	pickup_pool_loop.add_child(pickup_pool)
	pickup_pool_loop.set_pool_service(pickup_pool)
	pickup_pool_loop.experience_system = pickup_experience
	pickup_pool_loop.experience_pickup_scene = load(
		"res://scenes/pickups/ExperiencePickup.tscn"
	)
	pickup_pool_loop._spawn_experience_pickup(Vector2.ZERO, 3)
	var pooled_pickup = pickup_pool_loop.get_child(
		pickup_pool_loop.get_child_count() - 1
	)
	pooled_pickup.collect()
	pickup_pool_loop._spawn_experience_pickup(Vector2.ZERO, 5)
	var reused_pickup = pickup_pool_loop.get_child(
		pickup_pool_loop.get_child_count() - 1
	)
	runner.assert_true(
		reused_pickup == pooled_pickup,
		"game loop should reuse the released pickup"
	)
	pooled_pickup.collect()
	runner.assert_eq(
		pickup_experience.total,
		8,
		"reused pickup should keep exactly one collected connection"
	)
	pickup_experience.free()
	pickup_pool_loop.free()

	victory_panel.free()
	game_loop.free()
