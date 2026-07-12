extends RefCounted
class_name WeaponSimulator

const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const WeaponSystemScript = preload("res://scripts/systems/weapon_system.gd")
const TargetSelectorScript = preload("res://scripts/weapons/target_selector.gd")
const HitResolverScript = preload("res://scripts/systems/hit_resolver.gd")
const PoolServiceScript = preload("res://scripts/systems/pool_service.gd")
const HealthComponentScript = preload("res://scripts/components/health_component.gd")
const StatusControllerScript = preload("res://scripts/components/status_controller.gd")

const STEP := 1.0 / 60.0
const PLAYER_HIT_INTERVAL := 2.0
const TARGET_HEALTH := 240
const POOL_LIMITS := {
	"projectile": 250,
	"area": 24,
	"orbit": 32,
	"summon": 12,
}

var target_selector = TargetSelectorScript.new()
var hit_resolver = HitResolverScript.new()

func run(seed: int, duration: float, loadout: Array[String]) -> Dictionary:
	var report := _new_report()
	var database = GameDatabaseScript.new()
	if not database.load_all():
		report["invalid_request"] = database.errors.size()
		return report
	if loadout.is_empty() or loadout.size() > WeaponSystemScript.MAX_WEAPON_SLOTS:
		report["invalid_request"] = 1
		return report

	var weapon_system = WeaponSystemScript.new()
	for weapon_id in loadout:
		if not database.has_weapon(weapon_id):
			report["invalid_request"] = int(report["invalid_request"]) + 1
			continue
		var definition: Dictionary = database.get_weapon(weapon_id)
		if not weapon_system.add_weapon(definition):
			report["invalid_request"] = int(report["invalid_request"]) + 1
			continue
		for level in range(1, int(definition.get("max_level", 1))):
			weapon_system.level_weapon(weapon_id)
		_prepare_signature(report, weapon_id)

	var targets := _create_targets(seed)
	var pool_runtime := _create_pool_runtime(report)
	if pool_runtime.is_empty():
		for target in targets:
			target.free()
		weapon_system.free()
		return report
	var run_duration := maxf(0.0, duration)
	var elapsed := 0.0
	var player_hit_remaining := PLAYER_HIT_INTERVAL
	while elapsed + 0.000001 < run_duration:
		_release_expired(pool_runtime, elapsed)
		_tick_targets(targets, report)
		var requests: Array[Dictionary] = weapon_system.tick(STEP)
		player_hit_remaining -= STEP
		if player_hit_remaining <= 0.0:
			requests.append_array(
				weapon_system.notify_trigger("on_player_hit", { "damage": 8 })
			)
			player_hit_remaining += PLAYER_HIT_INTERVAL
		for request in requests:
			_simulate_request(
				request,
				targets,
				pool_runtime,
				elapsed,
				run_duration,
				report,
				weapon_system
			)
		elapsed += STEP

	report["pending_requests"] = weapon_system.pending_request_effects.size()
	_drain_pool(pool_runtime)
	report["pool_backend"] = "PoolService"
	report["pool_final"] = _pool_stats(pool_runtime)
	_finalize_signatures(report)
	for target in targets:
		if is_instance_valid(target):
			target.free()
	weapon_system.free()
	var pool_parent: Node = pool_runtime["parent"]
	pool_parent.free()
	return report

func _new_report() -> Dictionary:
	return {
		"requests": 0,
		"executed": 0,
		"no_target": 0,
		"pool_queued": 0,
		"invalid_request": 0,
		"hits_by_weapon": {},
		"statuses": {},
		"reactions": 0,
		"carrier_counts": {},
		"pool_peaks": {
			"projectile": 0,
			"area": 0,
			"orbit": 0,
			"summon": 0,
		},
		"signature": {},
		"_signature_accumulators": {},
	}

func _create_pool_runtime(report: Dictionary) -> Dictionary:
	var parent := Node.new()
	parent.name = "SimulationPoolRoot"
	var service = PoolServiceScript.new()
	service.name = "PoolService"
	parent.add_child(service)
	var scenes: Dictionary = {}
	var active: Dictionary = {}
	for carrier_id in POOL_LIMITS.keys():
		service.set_limit(carrier_id, int(POOL_LIMITS[carrier_id]))
		active[carrier_id] = []
		var prototype := Node.new()
		prototype.name = "Simulation%sCarrier" % String(carrier_id).capitalize()
		var scene := PackedScene.new()
		var pack_error := scene.pack(prototype)
		prototype.free()
		if pack_error != OK:
			report["invalid_request"] = int(report["invalid_request"]) + 1
			parent.free()
			return {}
		scenes[carrier_id] = scene
	return {
		"parent": parent,
		"service": service,
		"scenes": scenes,
		"active": active,
	}

func _create_targets(seed: int) -> Array[Node2D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var angle_offset := rng.randf_range(0.0, TAU)
	var targets: Array[Node2D] = []
	for index in range(12):
		var target := Node2D.new()
		target.name = "SimulationTarget%d" % index
		var radius := 112.0 + float(index % 4) * 44.0
		target.position = Vector2.RIGHT.rotated(
			angle_offset + TAU * float(index) / 12.0
		) * radius
		target.set_meta("simulation_anchor", target.position)
		var health = HealthComponentScript.new()
		health.name = "HealthComponent"
		target.add_child(health)
		health.configure(TARGET_HEALTH)
		var status = StatusControllerScript.new()
		status.name = "StatusController"
		target.add_child(status)
		status.configure(false)
		targets.append(target)
	return targets

func _tick_targets(targets: Array[Node2D], report: Dictionary) -> void:
	for target in targets:
		target.position = Vector2(target.get_meta("simulation_anchor", target.position))
		var health := target.get_node("HealthComponent")
		var status := target.get_node("StatusController")
		if health.is_dead():
			health.configure(TARGET_HEALTH)
			status.clear_all()
		for packet in status.tick_statuses(STEP):
			var result: Dictionary = hit_resolver.resolve_status_damage(target, packet)
			_record_hit_result(String(packet.get("source_weapon_id", "")), result, report)

func _simulate_request(
	request: Dictionary,
	targets: Array[Node2D],
	pool_runtime: Dictionary,
	elapsed: float,
	run_duration: float,
	report: Dictionary,
	weapon_system: Node
) -> void:
	report["requests"] = int(report["requests"]) + 1
	var weapon_id := String(request.get("weapon_id", ""))
	_record_signature_request(report, weapon_id, request)
	var target_value: Variant = request.get("target", {})
	var carrier_value: Variant = request.get("carrier", {})
	if typeof(target_value) != TYPE_DICTIONARY or typeof(carrier_value) != TYPE_DICTIONARY:
		_record_request_result(request, "invalid_request", report, weapon_system)
		return
	var carrier: Dictionary = carrier_value
	var carrier_id := String(carrier.get("id", ""))
	var requested_count := maxi(1, int(carrier.get("count", 1)))
	if (
		not POOL_LIMITS.has(carrier_id)
		or (carrier_id == "orbit" and requested_count > 8)
		or (carrier_id == "summon" and requested_count > 6)
	):
		_record_request_result(request, "invalid_request", report, weapon_system)
		return

	var selection := target_selector.select(
		target_value,
		Vector2.ZERO,
		targets,
		{
			"count": requested_count,
			"run_time": elapsed,
			"aim_direction": Vector2.RIGHT.rotated(elapsed * 0.37),
		}
	)
	if String(selection.get("status", "")) != "selected":
		_record_request_result(request, "no_target", report, weapon_system)
		return

	var spawn_count := requested_count if carrier_id in ["projectile", "orbit", "summon"] else 1
	var expiry := elapsed + _carrier_lifetime(carrier_id, carrier, target_value, run_duration)
	if not _reserve_pool(carrier_id, spawn_count, expiry, pool_runtime, report):
		_record_request_result(request, "pool_queued", report, weapon_system)
		return
	_record_request_result(request, "executed", report, weapon_system)
	_apply_simulated_hits(request, selection, targets, pool_runtime, elapsed, report)

func _record_request_result(
	request: Dictionary,
	result: String,
	report: Dictionary,
	weapon_system: Node
) -> void:
	report[result] = int(report.get(result, 0)) + 1
	weapon_system.acknowledge_request(int(request.get("request_id", 0)), result)

func _reserve_pool(
	carrier_id: String,
	count: int,
	expiry: float,
	pool_runtime: Dictionary,
	report: Dictionary
) -> bool:
	var service: Node = pool_runtime["service"]
	if not service.can_acquire(carrier_id, count):
		return false
	var scenes: Dictionary = pool_runtime["scenes"]
	var parent: Node = pool_runtime["parent"]
	var acquired: Array[Node] = []
	for index in range(count):
		var node: Node = service.acquire(carrier_id, scenes[carrier_id], parent)
		if node == null:
			for acquired_node in acquired:
				service.release(acquired_node)
			return false
		acquired.append(node)
	var active_by_carrier: Dictionary = pool_runtime["active"]
	var active: Array = active_by_carrier[carrier_id]
	for node in acquired:
		active.append({ "node": node, "expiry": expiry })
	active_by_carrier[carrier_id] = active
	var peaks: Dictionary = report["pool_peaks"]
	var stats: Dictionary = service.get_stats(carrier_id)
	peaks[carrier_id] = maxi(int(peaks.get(carrier_id, 0)), int(stats.get("active", 0)))
	var carrier_counts: Dictionary = report["carrier_counts"]
	carrier_counts[carrier_id] = int(carrier_counts.get(carrier_id, 0)) + count
	return true

func _carrier_lifetime(
	carrier_id: String,
	carrier: Dictionary,
	target: Dictionary,
	run_duration: float
) -> float:
	match carrier_id:
		"projectile":
			var speed := maxf(1.0, float(carrier.get("speed", 480.0)))
			return maxf(STEP, float(target.get("range", 360.0)) / speed)
		"area":
			return maxf(STEP, float(carrier.get("duration", 0.0)))
		"orbit":
			return run_duration + STEP
		"summon":
			return maxf(STEP, float(carrier.get("lifetime", 6.0)))
	return STEP

func _release_expired(pool_runtime: Dictionary, elapsed: float) -> void:
	var service: Node = pool_runtime["service"]
	var active_by_carrier: Dictionary = pool_runtime["active"]
	for carrier_id in active_by_carrier.keys():
		var active: Array = active_by_carrier[carrier_id]
		for index in range(active.size() - 1, -1, -1):
			var entry: Dictionary = active[index]
			if float(entry["expiry"]) <= elapsed + 0.000001:
				service.release(entry["node"])
				active.remove_at(index)
		active_by_carrier[carrier_id] = active

func _drain_pool(pool_runtime: Dictionary) -> void:
	var service: Node = pool_runtime["service"]
	var active_by_carrier: Dictionary = pool_runtime["active"]
	for carrier_id in active_by_carrier.keys():
		var active: Array = active_by_carrier[carrier_id]
		for entry_value in active:
			var entry: Dictionary = entry_value
			service.release(entry["node"])
		active.clear()

func _pool_stats(pool_runtime: Dictionary) -> Dictionary:
	var service: Node = pool_runtime["service"]
	var result: Dictionary = {}
	for carrier_id in POOL_LIMITS.keys():
		result[carrier_id] = service.get_stats(carrier_id)
	return result

func _apply_simulated_hits(
	request: Dictionary,
	selection: Dictionary,
	targets: Array[Node2D],
	pool_runtime: Dictionary,
	elapsed: float,
	report: Dictionary
) -> void:
	var carrier: Dictionary = request.get("carrier", {})
	var carrier_id := String(carrier.get("id", ""))
	var selected: Array[Node2D] = []
	for target_value in selection.get("targets", []):
		if target_value is Node2D:
			selected.append(target_value)
	if selected.is_empty():
		selected = _targets_by_distance(targets)
	var hit_slots := 1
	match carrier_id:
		"projectile":
			hit_slots = maxi(1, int(carrier.get("count", 1))) * (
				maxi(0, int(carrier.get("pierce", 0))) + 1
			)
		"area":
			selected = _targets_in_radius(
				targets,
				float(carrier.get("radius", Dictionary(request.get("target", {})).get("range", 0.0)))
			)
			hit_slots = selected.size()
		"orbit", "summon":
			hit_slots = maxi(1, int(carrier.get("count", 1)))
	if selected.is_empty():
		return
	for index in range(hit_slots):
		var target := selected[index % selected.size()]
		_reset_if_dead(target)
		var result: Dictionary = hit_resolver.resolve(
			target,
			_build_hit_packet(request, target.global_position)
		)
		_record_hit_result(String(request.get("weapon_id", "")), result, report)
		var splash_radius := float(Dictionary(request.get("hit", {})).get("splash_radius", 0.0))
		if splash_radius > 0.0:
			if not _reserve_pool("area", 1, elapsed + STEP, pool_runtime, report):
				report["pool_queued"] = int(report["pool_queued"]) + 1
				continue
			for splash_target in _targets_in_radius(targets, splash_radius, target.global_position):
				if splash_target == target:
					continue
				_reset_if_dead(splash_target)
				var splash_result: Dictionary = hit_resolver.resolve(
					splash_target,
					_build_hit_packet(request, target.global_position)
				)
				_record_hit_result(String(request.get("weapon_id", "")), splash_result, report)

func _build_hit_packet(request: Dictionary, hit_position: Vector2) -> Dictionary:
	var hit: Dictionary = request.get("hit", {})
	return {
		"source_weapon_id": String(request.get("weapon_id", "")),
		"source_instance_id": int(request.get("request_id", 0)),
		"base_damage": int(hit.get("damage", 0)),
		"damage_tags": ["direct"],
		"knockback": float(hit.get("knockback", 0.0)),
		"hit_position": hit_position,
		"status_payloads": Array(hit.get("statuses", [])).duplicate(true),
		"hit_effect_id": String(hit.get("hit_effect_id", "")),
	}

func _record_hit_result(weapon_id: String, result: Dictionary, report: Dictionary) -> void:
	if int(result.get("actual_damage", 0)) > 0 or not Array(result.get("applied_statuses", [])).is_empty():
		var hits: Dictionary = report["hits_by_weapon"]
		hits[weapon_id] = int(hits.get(weapon_id, 0)) + 1
	var statuses: Dictionary = report["statuses"]
	for status_id_value in result.get("applied_statuses", []):
		var status_id := String(status_id_value)
		statuses[status_id] = int(statuses.get(status_id, 0)) + 1
	if int(result.get("reaction_damage", 0)) > 0:
		report["reactions"] = int(report["reactions"]) + 1

func _reset_if_dead(target: Node2D) -> void:
	var health := target.get_node("HealthComponent")
	if not health.is_dead():
		return
	health.configure(TARGET_HEALTH)
	target.get_node("StatusController").clear_all()

func _targets_by_distance(targets: Array[Node2D]) -> Array[Node2D]:
	var result := targets.duplicate()
	result.sort_custom(func(left: Node2D, right: Node2D) -> bool:
		return left.global_position.length_squared() < right.global_position.length_squared()
	)
	return result

func _targets_in_radius(
	targets: Array[Node2D],
	radius: float,
	center: Vector2 = Vector2.ZERO
) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for target in targets:
		if center.distance_to(target.global_position) <= radius:
			result.append(target)
	return result

func _prepare_signature(report: Dictionary, weapon_id: String) -> void:
	var accumulators: Dictionary = report["_signature_accumulators"]
	accumulators[weapon_id] = {
		"requests": 0,
		"target_modes": {},
		"carriers": {},
		"count": 0,
		"area": 0,
		"statuses": {},
		"persistence": false,
	}
	var hits: Dictionary = report["hits_by_weapon"]
	hits[weapon_id] = 0

func _record_signature_request(report: Dictionary, weapon_id: String, request: Dictionary) -> void:
	var accumulators: Dictionary = report["_signature_accumulators"]
	if not accumulators.has(weapon_id):
		_prepare_signature(report, weapon_id)
	var signature: Dictionary = accumulators[weapon_id]
	signature["requests"] = int(signature["requests"]) + 1
	var target_modes: Dictionary = signature["target_modes"]
	target_modes[String(Dictionary(request.get("target", {})).get("id", ""))] = true
	var carrier: Dictionary = request.get("carrier", {})
	var carriers: Dictionary = signature["carriers"]
	carriers[String(carrier.get("id", ""))] = true
	signature["count"] = maxi(int(signature["count"]), int(carrier.get("count", 1)))
	var hit: Dictionary = request.get("hit", {})
	signature["area"] = maxi(
		int(signature["area"]),
		maxi(int(carrier.get("radius", 0)), int(hit.get("splash_radius", 0)))
	)
	var status_ids: Dictionary = signature["statuses"]
	for status_value in hit.get("statuses", []):
		status_ids[String(Dictionary(status_value).get("id", ""))] = true
	if String(Dictionary(request.get("trigger", {})).get("id", "")) == "persistent":
		signature["persistence"] = true

func _finalize_signatures(report: Dictionary) -> void:
	var result: Dictionary = report["signature"]
	var accumulators: Dictionary = report["_signature_accumulators"]
	for weapon_id in accumulators.keys():
		var accumulator: Dictionary = accumulators[weapon_id]
		result[weapon_id] = {
			"cadence": int(accumulator["requests"]),
			"target_mode": _joined_keys(accumulator["target_modes"]),
			"carrier": _joined_keys(accumulator["carriers"]),
			"count": int(accumulator["count"]),
			"area": int(accumulator["area"]),
			"status": _joined_keys(accumulator["statuses"]),
			"persistence": bool(accumulator["persistence"]),
		}
	report.erase("_signature_accumulators")

func _joined_keys(values: Dictionary) -> String:
	var keys: Array[String] = []
	for key in values.keys():
		if String(key) != "":
			keys.append(String(key))
	keys.sort()
	return ",".join(keys)
