extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/components/status_controller.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "status controller should exist")
		return

	var health_script = load("res://scripts/components/health_component.gd")
	var status_script = load(script_path)
	var target := Node2D.new()
	var health = health_script.new()
	var status = status_script.new()
	health.name = "HealthComponent"
	status.name = "StatusController"
	target.add_child(health)
	target.add_child(status)
	health.configure(100)
	status.configure(false)

	var emitted_packets: Array[Dictionary] = []
	status.status_damage_requested.connect(
		func(_target: Node, packet: Dictionary) -> void:
			emitted_packets.append(packet)
	)
	for index in range(4):
		status.apply_status(
			{ "id": "burn", "stacks": 1, "duration": 3.0 },
			{ "weapon_id": "talisman_fire" }
		)
	runner.assert_eq(status.get_snapshot()["burn"]["stacks"], 3, "burn should cap at three stacks")
	var burn_packets = status.tick_statuses(0.5)
	runner.assert_eq(burn_packets.size(), 1, "burn should tick every half second")
	runner.assert_eq(emitted_packets.size(), 1, "burn tick should emit one live damage request")
	runner.assert_eq(burn_packets[0]["base_damage"], 6, "burn should deal two damage per stack")

	status.clear_all()
	_apply_freeze_stack(status, 3)
	runner.assert_true(status.is_frozen(), "three chill applications should freeze")
	runner.assert_eq(status.get_movement_multiplier(), 0.0, "normal freeze should stop movement")
	runner.assert_eq(status.get_action_time_scale(), 0.0, "normal freeze should pause action time")
	status.tick_statuses(1.25)
	runner.assert_true(not status.is_frozen(), "freeze should end after 1.25 seconds")
	_apply_freeze_stack(status, 3)
	runner.assert_eq(status.get_snapshot()["freeze"]["stacks"], 1, "freeze immunity should limit chill to one stack")
	runner.assert_true(not status.is_frozen(), "freeze immunity should prevent immediate refreeze")

	status.clear_all()
	status.apply_status(
		{ "id": "seal", "stacks": 1, "duration": 1.0 },
		{ "weapon_id": "demon_sealing_bell" }
	)
	runner.assert_true(not status.can_start_special(), "seal should block new special actions")
	status.tick_statuses(1.0)
	runner.assert_true(status.can_start_special(), "expired seal should restore special actions")

	status.clear_all()
	_apply_freeze_stack(status, 3)
	var reaction = status.apply_status(
		{ "id": "burn", "stacks": 1, "duration": 3.0 },
		{ "weapon_id": "talisman_fire" }
	)
	runner.assert_eq(reaction["thermal_shatter_damage"], 18, "burn on frozen target should shatter for eighteen")
	runner.assert_true(not status.get_snapshot().has("burn"), "thermal shatter should consume burn")
	runner.assert_true(not status.get_snapshot().has("freeze"), "thermal shatter should consume freeze")
	_apply_freeze_stack(status, 3)
	var blocked_reaction = status.apply_status(
		{ "id": "burn", "stacks": 1, "duration": 3.0 },
		{ "weapon_id": "talisman_fire" }
	)
	runner.assert_eq(blocked_reaction["thermal_shatter_damage"], 0, "reaction cooldown should block immediate repeat")

	health.take_damage(100)
	var dead_application = status.apply_status(
		{ "id": "armor_break", "stacks": 1, "duration": 3.0 },
		{ "weapon_id": "mechanism_crossbow" }
	)
	runner.assert_true(dead_application.get("applied", true) != true, "dead targets should reject new statuses")
	target.free()

func _apply_freeze_stack(status: Node, count: int) -> void:
	for index in range(count):
		status.apply_status(
			{ "id": "freeze", "stacks": 1, "duration": 3.0 },
			{ "weapon_id": "frost_talisman" }
		)
