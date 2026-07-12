extends RefCounted

func run(runner) -> void:
	var resolver_path := "res://scripts/systems/hit_resolver.gd"
	var status_path := "res://scripts/components/status_controller.gd"
	if not ResourceLoader.exists(resolver_path) or not ResourceLoader.exists(status_path):
		runner.assert_true(false, "hit resolver and status controller should exist")
		return

	var target := Node2D.new()
	var health = load("res://scripts/components/health_component.gd").new()
	var status = load(status_path).new()
	health.name = "HealthComponent"
	status.name = "StatusController"
	target.add_child(health)
	target.add_child(status)
	health.configure(100)
	status.configure(false)
	var resolver = load(resolver_path).new()

	target.global_position = Vector2(10, 0)
	var direct_packet := _packet(10, "flying_sword")
	direct_packet["knockback"] = 5.0
	var direct = resolver.resolve(target, direct_packet)
	runner.assert_eq(direct["actual_damage"], 10, "direct hit should report actual damage")
	runner.assert_eq(health.current_health, 90, "direct hit should damage once")
	runner.assert_eq(target.get_meta("last_weapon_id", ""), "flying_sword", "direct hit should record source weapon")
	runner.assert_eq(target.global_position, Vector2(15, 0), "resolver should apply knockback away from hit position")

	status.apply_status(
		{ "id": "armor_break", "stacks": 1, "duration": 3.0 },
		{ "weapon_id": "mechanism_crossbow" }
	)
	resolver.resolve(target, _packet(10, "mechanism_crossbow"))
	runner.assert_eq(health.current_health, 78, "armor break should round 11.5 direct damage to twelve")
	resolver.resolve_status_damage(target, _packet(5, "talisman_fire", ["status_damage", "burn"]))
	runner.assert_eq(health.current_health, 73, "status damage should ignore armor break")

	status.clear_all()
	for index in range(3):
		status.apply_status(
			{ "id": "freeze", "stacks": 1, "duration": 3.0 },
			{ "weapon_id": "frost_talisman" }
		)
	var reaction_packet := _packet(0, "talisman_fire")
	reaction_packet["status_payloads"] = [{ "id": "burn", "stacks": 1, "duration": 3.0 }]
	var reaction = resolver.resolve(target, reaction_packet)
	runner.assert_eq(reaction["reaction_damage"], 18, "resolver should apply thermal shatter through status damage")
	runner.assert_eq(health.current_health, 55, "thermal shatter should subtract eighteen health")
	runner.assert_true(reaction["applied_statuses"].has("burn"), "resolver should report the attempted burn application")
	target.free()

func _packet(damage: int, weapon_id: String, tags: Array = ["direct"]) -> Dictionary:
	return {
		"source_weapon_id": weapon_id,
		"source_instance_id": 1,
		"base_damage": damage,
		"damage_tags": tags.duplicate(),
		"knockback": 0.0,
		"hit_position": Vector2.ZERO,
		"status_payloads": [],
		"hit_effect_id": "test_hit",
	}
