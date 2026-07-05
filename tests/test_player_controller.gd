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

	if player.has_method("set_external_move_vector"):
		player.set_external_move_vector(Vector2(3, 4))
		runner.assert_near(player.external_move_vector.length(), 1.0, 0.001, "external movement vector should clamp")
		runner.assert_eq(player._get_move_input(), player.external_move_vector, "external joystick input should drive movement")
	else:
		runner.assert_true(false, "player should accept an external move vector")

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
