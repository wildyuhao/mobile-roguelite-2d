extends RefCounted

func run(runner) -> void:
	var player_scene: PackedScene = load("res://scenes/player/Player.tscn")
	var enemy_scene: PackedScene = load("res://scenes/enemies/BasicDemon.tscn")
	var parent := Node2D.new()
	Engine.get_main_loop().root.add_child(parent)
	var player = player_scene.instantiate()
	var enemy = enemy_scene.instantiate()
	parent.add_child(player)
	parent.add_child(enemy)
	player.health = player.get_node("HealthComponent")
	player.collision_shape = player.get_node("CollisionShape2D")
	var player_feedback = player.get_node("HitFeedback")
	player.hit_feedback = player_feedback
	player_feedback.configure(
		player.get_node("AnimatedSprite2D"),
		player.get_node("HitSpark"),
		player.get_node("DamageLabel")
	)
	player._connect_hit_feedback()
	player.health.configure(player.base_max_health)

	player.global_position = Vector2.ZERO
	enemy.configure({
		"behavior": "chase",
		"contact_damage": 8,
		"collision_radius": 22.0,
		"attack_windup": 0.28,
		"attack_active": 0.10,
		"attack_recovery": 0.48,
		"max_health": 24,
	}, player)
	var enemy_feedback = enemy.get_node("HitFeedback")
	enemy.hit_feedback = enemy_feedback
	enemy_feedback.configure(
		enemy.get_node("Sprite2D"),
		enemy.get_node("HitSpark")
	)
	enemy._connect_health_signals()
	var edge_distance: float = float(
		enemy.get_contact_radius() + player.get_contact_radius() + 2.0
	)
	enemy.global_position = Vector2(edge_distance, 0.0)
	var player_health = player.get_node("HealthComponent")

	enemy.calculate_action_velocity(0.0)
	runner.assert_eq(enemy.action_state.state, "windup", "collision-edge contact should start windup")
	runner.assert_eq(player_health.current_health, 100, "windup should not deal damage")
	enemy.calculate_action_velocity(0.28)
	runner.assert_eq(enemy.action_state.state, "active", "windup completion should enter active")
	runner.assert_eq(player_health.current_health, 92, "active contact should deal exactly eight damage")
	runner.assert_true(player_feedback != null, "player should include hit feedback")
	if player_feedback != null:
		runner.assert_true(
			player_feedback.is_playing(),
			"contact damage should start player hit feedback"
		)
	runner.assert_true(enemy_feedback != null, "enemy should include hit feedback")
	if enemy_feedback != null:
		enemy.get_node("HealthComponent").take_damage(1)
		runner.assert_true(
			enemy_feedback.is_playing(),
			"enemy damage should start enemy hit feedback"
		)
	enemy.calculate_action_velocity(0.01)
	runner.assert_eq(player_health.current_health, 92, "one active window should not deal duplicate damage")
	runner.assert_true(not player.take_contact_damage(8), "player invulnerability should reject a second contact hit")
	runner.assert_eq(player_health.current_health, 92, "rejected contact damage should preserve health")

	parent.queue_free()
