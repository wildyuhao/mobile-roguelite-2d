extends Node
class_name EnemyDirector

const SPAWN_TIMER_EPSILON := 0.00001
const EncounterBagScript = preload("res://scripts/systems/encounter_bag.gd")
const PressureBudgetScript = preload("res://scripts/systems/pressure_budget.gd")
const FormationPlannerScript = preload("res://scripts/systems/formation_planner.gd")

signal enemy_spawned(enemy: Node)
signal boss_spawned(enemy: Node)
signal encounter_started(card_id: String)

@export var enemy_scene: PackedScene
@export var spawn_radius: float = 520.0
@export var encounter_seed: int = 20260712
@export var encounter_interval_min: float = 45.0
@export var encounter_interval_max: float = 60.0
@export var max_active_enemies: int = 140
@export var max_spawns_per_frame: int = 6

var database
var player: Node2D
var elapsed: float = 0.0
var wave_events: Array[Dictionary] = []
var triggered_events: Dictionary = {}
var pending_spawn_waves: Array[Dictionary] = []
var encounter_bag = EncounterBagScript.new()
var pressure_budget = PressureBudgetScript.new()
var formation_planner = FormationPlannerScript.new()
var interval_rng := RandomNumberGenerator.new()
var formations: Dictionary = {}
var enemy_definitions: Dictionary = {}
var next_encounter_time: float = 45.0
var active_enemies: Array[Node] = []

func configure(new_database, new_player: Node2D) -> void:
	database = new_database
	player = new_player
	wave_events = database.get_wave_events()
	elapsed = 0.0
	triggered_events.clear()
	pending_spawn_waves.clear()
	active_enemies.clear()
	formations = (
		database.get_formations()
		if database.has_method("get_formations")
		else {}
	)
	enemy_definitions = (
		database.get_enemies()
		if database.has_method("get_enemies")
		else {}
	)
	var cards: Array[Dictionary] = []
	if database.has_method("get_encounters"):
		cards = database.get_encounters()
	encounter_bag.configure(cards, encounter_seed)
	interval_rng.seed = encounter_seed ^ 0x5f3759df
	next_encounter_time = encounter_interval_min

func _process(delta: float) -> void:
	if database == null or player == null or enemy_scene == null:
		return

	elapsed += delta
	pressure_budget.tick(delta)
	_process_pending_spawn_waves(delta)
	for event in wave_events:
		var event_time := float(event.get("time", 0.0))
		if elapsed >= event_time and not triggered_events.has(event_time):
			triggered_events[event_time] = true
			_spawn_wave(event)
	if elapsed >= next_encounter_time:
		_try_schedule_encounter()
		next_encounter_time = elapsed + interval_rng.randf_range(
			encounter_interval_min,
			encounter_interval_max
		)

func _spawn_wave(event: Dictionary) -> void:
	var enemy_id: String = event.get("enemy_id", "basic_demon")
	var definition: Dictionary = database.get_enemy(enemy_id).duplicate(true)
	if bool(event.get("is_boss", false)):
		definition["is_boss"] = true
	var count := int(event.get("spawn_count", 1))
	pending_spawn_waves.append({
		"definition": definition,
		"spawn_count": count,
		"spawn_interval": max(0.0, float(event.get("spawn_interval", 0.0))),
		"spawned_count": 0,
		"time_until_next_spawn": 0.0,
		"positions": [],
		"encounter_id": "",
	})
	_process_pending_spawn_waves(0.0)

func _process_pending_spawn_waves(delta: float) -> void:
	var completed_waves: Array[Dictionary] = []
	var remaining_frame_spawns := max_spawns_per_frame
	for wave in pending_spawn_waves:
		if remaining_frame_spawns <= 0:
			break
		var spawned_count := int(wave.get("spawned_count", 0))
		var spawn_count := int(wave.get("spawn_count", 1))
		var spawn_interval := float(wave.get("spawn_interval", 0.0))
		var time_until_next_spawn := float(wave.get("time_until_next_spawn", 0.0)) - delta
		var positions: Array = wave.get("positions", [])
		var encounter_id := String(wave.get("encounter_id", ""))

		while (
			spawned_count < spawn_count
			and remaining_frame_spawns > 0
			and (
				spawn_interval <= 0.0
				or time_until_next_spawn <= SPAWN_TIMER_EPSILON
			)
		):
			var offset := Vector2.INF
			if spawned_count < positions.size():
				offset = positions[spawned_count]
			if not _spawn_enemy(
				wave["definition"],
				spawned_count,
				spawn_count,
				offset,
				encounter_id
			):
				time_until_next_spawn = maxf(0.1, spawn_interval)
				break
			spawned_count += 1
			remaining_frame_spawns -= 1
			if spawn_interval > 0.0:
				time_until_next_spawn += spawn_interval

		wave["spawned_count"] = spawned_count
		wave["time_until_next_spawn"] = time_until_next_spawn
		if spawned_count >= spawn_count:
			completed_waves.append(wave)

	for wave in completed_waves:
		pending_spawn_waves.erase(wave)

func notify_player_heavy_damage() -> void:
	pressure_budget.notify_heavy_damage()

func _try_schedule_encounter() -> bool:
	var card: Dictionary = encounter_bag.draw(
		elapsed,
		pressure_budget.get_budget(elapsed)
	)
	if card.is_empty():
		return false
	var snapshot := _get_active_snapshot()
	if not pressure_budget.can_schedule(
		card,
		enemy_definitions,
		snapshot["roles"],
		snapshot["total"],
		max_active_enemies
	):
		return false
	_queue_encounter(card)
	encounter_started.emit(String(card.get("id", "")))
	return true

func _get_active_snapshot() -> Dictionary:
	var roles: Dictionary = {}
	var total := 0
	for enemy in _get_active_enemies():
		total += 1
		var role := String(enemy.get_meta("enemy_role", "swarm"))
		roles[role] = int(roles.get(role, 0)) + 1
	return {"roles": roles, "total": total}

func _queue_encounter(card: Dictionary) -> void:
	var total_count := 0
	for group in card.get("groups", []):
		total_count += int(group.get("count", 0))
	var formation: Dictionary = formations.get(
		String(card.get("formation_id", "")),
		{}
	)
	var angle := interval_rng.randf_range(-PI, PI)
	var slots := formation_planner.build_slots(
		formation,
		total_count,
		spawn_radius,
		angle
	)
	var slot_index := 0
	for group in card.get("groups", []):
		var enemy_id := String(group.get("enemy_id", "basic_demon"))
		var count := int(group.get("count", 0))
		var definition: Dictionary = database.get_enemy(enemy_id).duplicate(true)
		var positions: Array[Vector2] = []
		for index in range(count):
			positions.append(slots[slot_index])
			slot_index += 1
		pending_spawn_waves.append({
			"definition": definition,
			"spawn_count": count,
			"spawn_interval": 0.12,
			"spawned_count": 0,
			"time_until_next_spawn": 0.0,
			"positions": positions,
			"encounter_id": String(card.get("id", "")),
		})

func _spawn_enemy(
	definition: Dictionary,
	index: int,
	count: int,
	offset: Vector2 = Vector2.INF,
	encounter_id: String = ""
) -> bool:
	if _get_active_enemies().size() >= max_active_enemies:
		return false
	var enemy = enemy_scene.instantiate()
	get_parent().add_child(enemy)
	active_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy), CONNECT_ONE_SHOT)
	var resolved_offset := (
		Vector2.RIGHT.rotated(TAU * float(index) / max(1, count)) * spawn_radius
		if offset == Vector2.INF
		else offset
	)
	enemy.global_position = player.global_position + resolved_offset
	enemy.set_meta("enemy_role", String(definition.get("role", "swarm")))
	if encounter_id != "":
		enemy.set_meta("encounter_id", encounter_id)
	enemy.configure(definition, player)
	enemy_spawned.emit(enemy)
	if bool(definition.get("is_boss", false)) or definition.get("behavior", "") == "boss":
		boss_spawned.emit(enemy)
	return true

func _get_active_enemies() -> Array[Node]:
	_prune_active_enemies()
	var result: Array[Node] = []
	for enemy in active_enemies:
		result.append(enemy)
	return result

func _prune_active_enemies() -> void:
	for index in range(active_enemies.size() - 1, -1, -1):
		var enemy := active_enemies[index]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			active_enemies.remove_at(index)

func _on_enemy_tree_exited(enemy: Node) -> void:
	active_enemies.erase(enemy)
