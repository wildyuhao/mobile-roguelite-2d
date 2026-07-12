extends RefCounted

class ContactTarget:
	extends Node2D

	var contact_radius: float = 18.0
	var damage_amounts: Array[int] = []

	func get_contact_radius() -> float:
		return contact_radius

	func take_contact_damage(amount: int) -> bool:
		damage_amounts.append(amount)
		return true

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/enemies/enemy_agent.gd"):
		runner.assert_true(false, "enemy agent script should exist")
		return
	if not ResourceLoader.exists("res://scripts/components/health_component.gd"):
		runner.assert_true(false, "health component script should exist")
		return

	var enemy_script = load("res://scripts/enemies/enemy_agent.gd")
	var health_script = load("res://scripts/components/health_component.gd")
	var enemy = enemy_script.new()
	var health = health_script.new()
	var sprite := Sprite2D.new()
	var collision := CollisionShape2D.new()
	var collision_shape := CircleShape2D.new()
	var target := Node2D.new()
	var status_controller: Node = null
	health.name = "HealthComponent"
	sprite.name = "Sprite2D"
	collision.name = "CollisionShape2D"
	collision_shape.radius = 16.0
	collision.shape = collision_shape
	enemy.add_child(health)
	enemy.add_child(sprite)
	enemy.add_child(collision)
	if ResourceLoader.exists("res://scripts/components/status_controller.gd"):
		status_controller = load("res://scripts/components/status_controller.gd").new()
		status_controller.name = "StatusController"
		enemy.add_child(status_controller)
	else:
		runner.assert_true(false, "enemy should have a status controller implementation")
	enemy.health = health
	if _has_property(enemy, "status_controller"):
		enemy.status_controller = status_controller
	else:
		runner.assert_true(false, "enemy agent should expose its status controller")
	enemy.global_position = Vector2(12, 34)
	enemy.configure({
		"max_health": 1200,
		"move_speed": 70,
		"experience_value": 30,
		"material_value": 50,
		"behavior": "boss",
		"sprite_path": "res://art/enemies/seal_boss/seal_boss_front.png",
		"sprite_scale": 0.32,
		"collision_radius": 44.0,
	}, target)

	runner.assert_eq(enemy.get("material_value"), 50, "enemy configure should set material value")
	runner.assert_eq(enemy.get("is_boss"), true, "enemy configure should mark boss enemies")
	runner.assert_true(sprite.texture != null, "enemy configure should load sprite_path into Sprite2D")
	runner.assert_eq(sprite.scale, Vector2(0.32, 0.32), "enemy configure should apply sprite scale")
	runner.assert_eq((collision.shape as CircleShape2D).radius, 44.0, "enemy configure should apply collision radius")
	if enemy.has_method("get_defeat_payload"):
		enemy.set_meta("last_weapon_id", "flying_sword")
		var payload = enemy.get_defeat_payload()
		runner.assert_eq(payload["enemy_position"], Vector2(12, 34), "defeat payload should include position")
		runner.assert_eq(payload["experience_value"], 30, "defeat payload should include experience")
		runner.assert_eq(payload["material_value"], 50, "defeat payload should include materials")
		runner.assert_eq(payload["is_boss"], true, "defeat payload should include boss flag")
		runner.assert_eq(payload.get("source_weapon_id", ""), "flying_sword", "defeat payload should include weapon attribution")
	else:
		runner.assert_true(false, "enemy should expose a defeat payload")

	if enemy.has_method("calculate_desired_velocity"):
		target.global_position = Vector2(112, 34)
		var boss_velocity = enemy.calculate_desired_velocity(0.1)
		runner.assert_near(boss_velocity.length(), 70.0, 0.01, "boss chase velocity should use move speed")

		enemy.configure({
			"behavior": "charge",
			"move_speed": 95,
			"charge_speed": 260,
			"max_health": 38,
		}, target)
		var charge_velocity = enemy.calculate_desired_velocity(0.1)
		runner.assert_near(charge_velocity.length(), 95.0, 0.01, "charging enemy should approach at locomotion speed before windup")

		enemy.global_position = Vector2.ZERO
		target.global_position = Vector2(100, 0)
		enemy.configure({
			"behavior": "ranged",
			"move_speed": 80,
			"preferred_range": 320,
			"max_health": 28,
		}, target)
		var retreat_velocity = enemy.calculate_desired_velocity(0.1)
		runner.assert_true(retreat_velocity.x < 0.0, "ranged enemy should retreat when too close")

		target.global_position = Vector2(600, 0)
		var approach_velocity = enemy.calculate_desired_velocity(0.1)
		runner.assert_true(approach_velocity.x > 0.0, "ranged enemy should approach when too far")
	else:
		runner.assert_true(false, "enemy should calculate behavior-specific velocity")

	if enemy.has_method("calculate_action_velocity"):
		var timed_target := ContactTarget.new()
		timed_target.global_position = Vector2(18, 0)
		enemy.global_position = Vector2.ZERO
		enemy.configure({
			"behavior": "chase",
			"contact_damage": 11,
			"collision_radius": 18.0,
			"max_health": 24,
			"attack_windup": 0.28,
			"attack_active": 0.10,
			"attack_recovery": 0.48,
		}, timed_target)
		var windup_velocity = enemy.calculate_action_velocity(0.0)
		runner.assert_eq(
			windup_velocity,
			Vector2.ZERO,
			"contact attack should stop during windup"
		)
		runner.assert_eq(
			enemy.action_state.state,
			"windup",
			"contact range should begin windup"
		)
		runner.assert_eq(
			timed_target.damage_amounts.size(),
			0,
			"windup should not deal contact damage"
		)
		enemy.calculate_action_velocity(0.28)
		runner.assert_eq(
			enemy.action_state.state,
			"active",
			"completed contact windup should enter active"
		)
		runner.assert_eq(
			timed_target.damage_amounts.size(),
			1,
			"active contact frame should deal one hit"
		)
		timed_target.free()

		var charge_target := ContactTarget.new()
		charge_target.global_position = Vector2(200, 0)
		enemy.global_position = Vector2.ZERO
		enemy.configure({
			"behavior": "charge",
			"move_speed": 95,
			"charge_speed": 260,
			"charge_trigger_range": 360,
			"attack_windup": 0.55,
			"attack_active": 0.45,
			"attack_recovery": 0.65,
			"max_health": 38,
		}, charge_target)
		runner.assert_eq(
			enemy.calculate_action_velocity(0.0),
			Vector2.ZERO,
			"charge trigger should begin a stationary windup"
		)
		runner.assert_eq(
			enemy.action_state.state,
			"windup",
			"charge should visibly wind up"
		)
		var active_charge_velocity = enemy.calculate_action_velocity(0.55)
		runner.assert_near(
			active_charge_velocity.length(),
			260.0,
			0.01,
			"active charge should use charge speed"
		)
		runner.assert_eq(
			enemy.action_state.state,
			"active",
			"charge should enter active after windup"
		)
		charge_target.free()

		if status_controller != null:
			enemy.global_position = Vector2.ZERO
			target.global_position = Vector2(300, 0)
			enemy.configure({
				"behavior": "charge",
				"move_speed": 95,
				"charge_speed": 260,
				"charge_trigger_range": 360,
				"max_health": 38,
			}, target)
			status_controller.apply_status(
				{ "id": "seal", "stacks": 1, "duration": 1.0 },
				{ "weapon_id": "demon_sealing_bell" }
			)
			var sealed_velocity = enemy.calculate_action_velocity(0.0)
			runner.assert_eq(enemy.action_state.state, "locomotion", "seal should prevent a new charge windup")
			runner.assert_near(sealed_velocity.length(), 95.0, 0.01, "sealed charger should keep basic locomotion")

			enemy.configure({
				"behavior": "chase",
				"move_speed": 80,
				"max_health": 40,
			}, target)
			for index in range(3):
				status_controller.apply_status(
					{ "id": "freeze", "stacks": 1, "duration": 3.0 },
					{ "weapon_id": "frost_talisman" }
				)
			runner.assert_eq(enemy.calculate_action_velocity(0.1), Vector2.ZERO, "freeze should stop enemy movement")
			enemy.action_state.start_attack(0.3, 0.1, 0.4)
			var frozen_remaining := float(enemy.action_state.remaining)
			enemy.calculate_action_velocity(0.5)
			runner.assert_eq(enemy.action_state.state, "windup", "freeze should not skip attack windup")
			runner.assert_near(float(enemy.action_state.remaining), frozen_remaining, 0.001, "freeze should pause action remaining time")
	else:
		runner.assert_true(false, "enemy should gate movement through action timing")

	var contact_target := ContactTarget.new()
	contact_target.global_position = Vector2(18, 0)
	enemy.global_position = Vector2.ZERO
	enemy.configure({
		"behavior": "chase",
		"contact_damage": 14,
		"collision_radius": 18.0,
		"max_health": 24,
	}, contact_target)
	if enemy.has_method("try_apply_contact_damage"):
		runner.assert_true(enemy.try_apply_contact_damage(), "enemy should apply contact damage in range")
		runner.assert_eq(contact_target.damage_amounts[0], 14, "enemy should pass configured contact damage")
	else:
		runner.assert_true(false, "enemy should expose contact damage application")

	if enemy.has_signal("release_requested") and enemy.has_method("deactivate_for_pool"):
		var release_requests: Array[Node] = []
		enemy.release_requested.connect(
			func(node: Node) -> void: release_requests.append(node)
		)
		enemy.set_meta("encounter_id", "old_encounter")
		enemy.set_meta("enemy_role", "charger")
		enemy.set_meta("last_weapon_id", "old_weapon")
		enemy.action_state.start_attack(0.1, 0.1, 0.1)
		enemy.deactivate_for_pool()
		runner.assert_true(not enemy.is_pool_active(), "deactivated enemy should be inactive")
		runner.assert_true(not enemy.has_meta("encounter_id"), "deactivation should clear encounter metadata")
		runner.assert_true(not enemy.has_meta("enemy_role"), "deactivation should clear role metadata")
		runner.assert_true(not enemy.has_meta("last_weapon_id"), "deactivation should clear weapon attribution")
		enemy.activate_from_pool()
		enemy.configure({"max_health": 77, "behavior": "chase"}, target)
		runner.assert_true(enemy.is_pool_active(), "reactivated enemy should be active")
		runner.assert_eq(health.current_health, 77, "reactivation should restore configured health")
		runner.assert_eq(enemy.action_state.state, "locomotion", "reactivation should reset action state")
		runner.assert_eq(enemy.move_speed, 110.0, "reuse should reset omitted move speed")
		runner.assert_eq(enemy.charge_speed, 240.0, "reuse should reset omitted charge speed")
		runner.assert_eq(enemy.preferred_range, 300.0, "reuse should reset omitted preferred range")
		runner.assert_eq(enemy.attack_windup, 0.28, "reuse should reset omitted attack windup")
		runner.assert_eq(enemy.contact_damage, 8, "reuse should reset omitted contact damage")
		runner.assert_eq(enemy.contact_reach_padding, 4.0, "reuse should reset contact reach padding")
		enemy._on_died()
		runner.assert_eq(release_requests, [enemy], "pooled enemy death should request one release")
	else:
		runner.assert_true(false, "enemy should expose a pool lifecycle")

	contact_target.free()
	enemy.free()
	target.free()

func _has_property(instance: Object, property_name: String) -> bool:
	for property in instance.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
