extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/player/player_controller.gd"):
		runner.assert_true(false, "player controller script should exist")
		return
	if not ResourceLoader.exists("res://scripts/components/health_component.gd"):
		runner.assert_true(false, "health component script should exist")
		return

	var player_script = load("res://scripts/player/player_controller.gd")
	var health_script = load("res://scripts/components/health_component.gd")
	var player = player_script.new()
	var health = health_script.new()
	health.name = "HealthComponent"
	player.add_child(health)
	player.health = health
	health.configure(100)

	if player.has_method("apply_stat_modifiers"):
		player.apply_stat_modifiers({
			"max_health": 30,
			"move_speed": 18,
		})
		runner.assert_eq(health.max_health, 130, "equipment max health should increase player max health")
		runner.assert_eq(health.current_health, 130, "equipment max health should refill starting health")
		runner.assert_eq(player.move_speed, 278.0, "equipment move speed should increase player speed")
		health.take_damage(40)
		player.apply_stat_modifiers({
			"max_health": 30,
			"move_speed": 18,
		})
		runner.assert_eq(
			health.current_health,
			90,
			"reapplying runtime modifiers should preserve existing damage"
		)
		player.apply_stat_modifiers({
			"max_health": 40,
			"move_speed": 18,
		})
		runner.assert_eq(
			health.current_health,
			100,
			"max health upgrades should grant only newly added health"
		)
		player.apply_stat_modifiers({
			"max_health": 10,
			"move_speed": 5,
		})
		runner.assert_eq(health.max_health, 110, "reapplying modifiers should use base max health")
		runner.assert_eq(player.move_speed, 265.0, "reapplying modifiers should use base move speed")
		player.apply_stat_modifiers({})
		runner.assert_eq(health.max_health, 100, "empty modifiers should restore base max health")
		runner.assert_eq(player.move_speed, 260.0, "empty modifiers should restore base move speed")
	else:
		runner.assert_true(false, "player should accept equipment stat modifiers")

	if player.has_method("set_external_move_vector"):
		player.set_external_move_vector(Vector2(3, 4))
		runner.assert_near(player.external_move_vector.length(), 1.0, 0.001, "external movement vector should clamp")
		runner.assert_eq(player._get_move_input(), player.external_move_vector, "external joystick input should drive movement")
	else:
		runner.assert_true(false, "player should accept an external move vector")

	if (
		player.has_method("start_starting_ward")
		and player.has_method("tick_starting_ward")
		and player.has_method("is_starting_ward_active")
		and player.has_method("get_starting_ward_ratio")
	):
		player.starting_ward_seconds = 6.0
		player.start_starting_ward()
		runner.assert_true(player.is_starting_ward_active(), "starting ward should activate at run start")
		runner.assert_near(player.get_starting_ward_ratio(), 1.0, 0.001, "fresh ward should report full ratio")
		runner.assert_true(not player.take_contact_damage(12), "starting ward should reject enemy damage")
		runner.assert_eq(health.current_health, 100, "blocked starting damage should preserve health")
		player.tick_starting_ward(0.0)
		runner.assert_near(player.get_starting_ward_ratio(), 1.0, 0.001, "zero delta should not consume the ward")
		player.tick_starting_ward(4.5)
		runner.assert_near(player.get_starting_ward_ratio(), 0.25, 0.001, "ward ratio should follow remaining time")
		player.tick_starting_ward(1.5)
		runner.assert_true(not player.is_starting_ward_active(), "ward should expire after six active seconds")
	else:
		runner.assert_true(false, "player should expose starting ward state methods")

	if player.has_method("take_contact_damage") and player.has_method("tick_damage_invulnerability"):
		runner.assert_true(player.take_contact_damage(12), "first contact damage should apply")
		runner.assert_eq(health.current_health, 88, "contact damage should reduce health")
		runner.assert_true(not player.take_contact_damage(12), "contact damage should be blocked during invulnerability")
		runner.assert_eq(health.current_health, 88, "blocked contact damage should not reduce health")
		player.tick_damage_invulnerability(0.6)
		runner.assert_true(player.take_contact_damage(12), "contact damage should apply after invulnerability ends")
		runner.assert_eq(health.current_health, 76, "second valid contact damage should reduce health")
	else:
		runner.assert_true(false, "player should expose contact damage and invulnerability methods")

	player.free()
