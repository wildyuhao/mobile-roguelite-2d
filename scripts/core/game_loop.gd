extends Node2D
class_name GameLoop

const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const UpgradeSystemScript = preload("res://scripts/systems/upgrade_system.gd")
const SettlementSystemScript = preload("res://scripts/systems/settlement_system.gd")
const SaveSystemScript = preload("res://scripts/systems/save_system.gd")
const EquipmentSystemScript = preload("res://scripts/systems/equipment_system.gd")
const SETTLEMENT_UPGRADE_EQUIPMENT_ID := "talisman_robe"
const SETTLEMENT_UPGRADE_EQUIPMENT_IDS := ["talisman_robe", "cloudstep_boots", "bronze_gear_core", "jade_compass"]

@export var experience_pickup_scene: PackedScene

@onready var player: Node2D = $Player
@onready var enemy_director: Node = $EnemyDirector
@onready var experience_system: Node = $ExperienceSystem
@onready var weapon_system: Node = $WeaponSystem
@onready var hud: Node = $HUD
@onready var upgrade_choice_panel: Node = $UpgradeChoicePanel
@onready var virtual_joystick: Node = $VirtualJoystick/Stick
@onready var settlement_panel: Node = $SettlementPanel
@onready var pool_service: Node = get_node_or_null("PoolService")
@onready var combat_effect_pipeline: Node = get_node_or_null("CombatEffectPipeline")

var database = GameDatabaseScript.new()
var upgrade_system = UpgradeSystemScript.new()
var settlement_system = SettlementSystemScript.new()
var save_system: Object = SaveSystemScript.new()
var equipment_system = EquipmentSystemScript.new()
var runtime_state := {
	"owned_weapons": { "flying_sword": 1 },
	"upgrade_stacks": {},
	"max_weapon_slots": 4,
}
var run_summary := {
	"defeated_enemies": 0,
	"base_materials": 0,
	"boss_defeated": false,
}
var equipment_modifiers: Dictionary = {}
var active_stat_modifiers: Dictionary = {}
var settlement_rewards := {}
var settlement_saved: bool = false
var run_ended: bool = false
var run_time: float = 0.0

func _ready() -> void:
	var loaded = database.load_all()
	assert(loaded, "Game database failed to load: %s" % str(database.errors))
	if pool_service != null and pool_service.has_method("prewarm"):
		pool_service.prewarm("pickup", experience_pickup_scene, self, 32)
	if (
		combat_effect_pipeline != null
		and combat_effect_pipeline.has_method("prepare_runtime")
	):
		combat_effect_pipeline.prepare_runtime(pool_service, self)

	var save_data := _load_save_data()
	apply_saved_equipment_to_player(save_data)
	upgrade_system.configure(database.get_upgrades())
	weapon_system.add_weapon(database.get_weapon("flying_sword"))
	enemy_director.enemy_spawned.connect(_on_enemy_spawned)
	enemy_director.configure(database, player)
	virtual_joystick.move_vector_changed.connect(player.set_external_move_vector)
	_connect_settlement_panel_signals()
	_connect_player_health()
	experience_system.level_up.connect(_on_level_up)
	experience_system.experience_changed.connect(hud.set_experience)
	upgrade_choice_panel.upgrade_selected.connect(_on_upgrade_selected)
	hud.set_level(experience_system.level)
	hud.set_experience(experience_system.current_experience, experience_system.get_required_experience())

func _process(delta: float) -> void:
	if run_ended:
		return

	run_time += delta
	hud.set_run_time(run_time)

	var combat_context := _build_combat_context()
	if combat_effect_pipeline != null:
		combat_effect_pipeline.update_context(combat_context)
	_execute_effect_requests(weapon_system.tick(delta), combat_context)

func _build_combat_context() -> Dictionary:
	var targets: Array = []
	if is_inside_tree():
		targets = get_tree().get_nodes_in_group("enemy")
	var origin := player.global_position if player != null else Vector2.ZERO
	return {
		"origin": origin,
		"owner": player,
		"targets": targets,
		"pool_service": pool_service,
		"parent": self,
		"run_time": run_time,
		"aim_direction": Vector2.ZERO,
	}

func _execute_effect_requests(requests: Array, context: Dictionary) -> void:
	if combat_effect_pipeline == null:
		return
	for request_value in requests:
		if typeof(request_value) != TYPE_DICTIONARY:
			continue
		var request: Dictionary = request_value
		var result := String(combat_effect_pipeline.execute_request(request, context))
		if weapon_system != null and weapon_system.has_method("acknowledge_request"):
			weapon_system.acknowledge_request(
				int(request.get("request_id", 0)),
				result
			)

func _forward_weapon_trigger(trigger_id: String, payload: Dictionary) -> void:
	if weapon_system == null or not weapon_system.has_method("notify_trigger"):
		return
	_execute_effect_requests(
		weapon_system.notify_trigger(trigger_id, payload),
		_build_combat_context()
	)

func set_pool_service(service: Node) -> void:
	pool_service = service

func _acquire_runtime_node(pool_key: String, scene: PackedScene) -> Node:
	if scene == null:
		return null
	if pool_service != null and pool_service.has_method("acquire"):
		return pool_service.acquire(pool_key, scene, self)
	var node = scene.instantiate()
	add_child(node)
	return node

func _on_level_up(new_level: int) -> void:
	hud.set_level(new_level)
	get_tree().paused = true
	var choices: Array[Dictionary] = upgrade_system.get_choices(runtime_state, 3)
	upgrade_choice_panel.show_choices(choices)

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	if not _try_apply_runtime_upgrade(upgrade):
		get_tree().paused = false
		return
	_apply_total_stat_modifiers()
	_show_runtime_upgrade_feedback(upgrade)
	get_tree().paused = false

func _try_apply_runtime_upgrade(upgrade: Dictionary) -> bool:
	var kind := String(upgrade.get("kind", ""))
	var weapon_definition: Dictionary = {}
	if kind == "weapon_unlock":
		var weapon_id := String(upgrade.get("weapon_id", ""))
		if weapon_id == "":
			return false
		weapon_definition = database.get_weapon(weapon_id)
		if weapon_definition.is_empty() or not weapon_system.can_add_weapon(weapon_definition):
			return false

	var state_before := runtime_state.duplicate(true)
	if not upgrade_system.apply_upgrade(runtime_state, upgrade):
		return false
	if upgrade.get("kind", "") == "weapon_level":
		weapon_system.level_weapon(upgrade.get("weapon_id", ""))
	elif kind == "weapon_unlock" and not weapon_system.add_weapon(weapon_definition):
		runtime_state.clear()
		runtime_state.merge(state_before, true)
		return false
	return true

func _on_enemy_spawned(enemy: Node) -> void:
	if combat_effect_pipeline != null:
		combat_effect_pipeline.register_target(enemy)
	if not enemy.has_signal("defeated"):
		return
	var callback := Callable(self, "_on_enemy_defeated")
	if not enemy.is_connected("defeated", callback):
		enemy.connect("defeated", callback)

func _on_enemy_defeated(payload: Dictionary) -> void:
	_forward_weapon_trigger("on_kill", payload)
	record_enemy_defeat(payload)
	var enemy_position: Vector2 = payload.get("enemy_position", Vector2.ZERO)
	var experience_value := int(payload.get("experience_value", 0))
	if experience_pickup_scene == null:
		experience_system.add_experience(experience_value)
		return

	call_deferred("_spawn_experience_pickup", enemy_position, experience_value)

func _spawn_experience_pickup(enemy_position: Vector2, experience_value: int) -> void:
	if experience_pickup_scene == null:
		if experience_system != null and experience_system.has_method("add_experience"):
			experience_system.add_experience(experience_value)
		return

	var pickup = _acquire_runtime_node("pickup", experience_pickup_scene)
	if pickup == null:
		return
	pickup.global_position = enemy_position
	if pickup.has_method("configure"):
		pickup.configure(experience_value)
	configure_pickup_collection_radius(pickup)
	if (
		experience_system != null
		and pickup.has_signal("collected")
		and experience_system.has_method("add_experience")
	):
		var callback := Callable(experience_system, "add_experience")
		if not pickup.is_connected("collected", callback):
			pickup.connect("collected", callback)

func record_enemy_defeat(payload: Dictionary) -> Dictionary:
	if run_ended:
		return run_summary

	run_summary["defeated_enemies"] = int(run_summary.get("defeated_enemies", 0)) + 1
	run_summary["base_materials"] = int(run_summary.get("base_materials", 0)) + int(payload.get("material_value", 0))
	if bool(payload.get("is_boss", false)):
		run_summary["boss_defeated"] = true
		run_ended = true
		settlement_rewards = _calculate_settlement_rewards()
		_persist_settlement_rewards()
		_show_settlement_result("封印成功")
	return run_summary

func record_player_defeat() -> Dictionary:
	if run_ended:
		return run_summary

	run_summary["boss_defeated"] = false
	run_summary["player_defeated"] = true
	run_ended = true
	settlement_rewards = _calculate_settlement_rewards()
	_persist_settlement_rewards()
	_show_settlement_result("挑战失败")
	if is_inside_tree():
		get_tree().paused = true
	return run_summary

func _calculate_settlement_rewards() -> Dictionary:
	var summary := run_summary.duplicate(true)
	summary["material_gain"] = float(active_stat_modifiers.get("material_gain", 0.0))
	return settlement_system.calculate_rewards(summary)

func set_settlement_panel(panel: Node) -> void:
	settlement_panel = panel
	_connect_settlement_panel_signals()

func set_save_system(system: Object) -> void:
	save_system = system

func upgrade_settlement_equipment(equipment_id: String) -> Dictionary:
	if not _ensure_database_loaded():
		return { "success": false, "reason": "database_not_loaded" }
	if save_system == null or not save_system.has_method("save_game"):
		return { "success": false, "reason": "save_unavailable" }

	var save_data := _load_save_data()
	equipment_system.configure(database.get_equipment())
	var result: Dictionary = equipment_system.upgrade_equipment_in_save(equipment_id, save_data)
	if bool(result.get("success", false)):
		save_system.save_game(save_data)
		_refresh_settlement_upgrade_offer()
		_show_settlement_upgrade_feedback(equipment_id, int(result.get("level", 1)))
	return result

func apply_saved_equipment_to_player(save_data: Dictionary) -> Dictionary:
	equipment_system.configure(database.get_equipment())
	equipment_system.set_equipment_levels(save_data.get("equipment_levels", {}))
	equipment_system.equip(save_data.get("unlocked_equipment", []))
	equipment_modifiers = equipment_system.get_total_modifiers()
	return _apply_total_stat_modifiers()

func configure_pickup_collection_radius(pickup: Node) -> void:
	if pickup != null and pickup.has_method("set_collection_radius_bonus"):
		pickup.set_collection_radius_bonus(float(active_stat_modifiers.get("pickup_radius", 0.0)))

func _apply_total_stat_modifiers() -> Dictionary:
	var modifiers := _merge_stat_modifiers(equipment_modifiers, upgrade_system.get_stat_modifiers(runtime_state))
	active_stat_modifiers = modifiers.duplicate(true)
	if player != null and player.has_method("apply_stat_modifiers"):
		player.apply_stat_modifiers(modifiers)
		var player_health := player.get_node_or_null("HealthComponent")
		if player_health != null:
			_update_player_health_hud(player_health)
	if weapon_system != null and weapon_system.has_method("set_stat_modifiers"):
		weapon_system.set_stat_modifiers(modifiers)
	return modifiers

func _merge_stat_modifiers(base_modifiers: Dictionary, extra_modifiers: Dictionary) -> Dictionary:
	var merged := base_modifiers.duplicate(true)
	for key in extra_modifiers.keys():
		merged[key] = float(merged.get(key, 0.0)) + float(extra_modifiers[key])
	return _normalize_number_types(merged)

func _normalize_number_types(values: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for key in values.keys():
		var value := float(values[key])
		normalized[key] = int(value) if is_equal_approx(value, round(value)) else value
	return normalized

func _load_save_data() -> Dictionary:
	if save_system == null or not save_system.has_method("load_game"):
		return {}

	var save_data = save_system.load_game()
	if typeof(save_data) != TYPE_DICTIONARY:
		return {}
	return save_data

func _ensure_database_loaded() -> bool:
	if not database.get_equipment().is_empty():
		return true
	return database.load_all()

func _connect_settlement_panel_signals() -> void:
	if settlement_panel == null:
		return
	if settlement_panel.has_signal("restart_requested") and not settlement_panel.restart_requested.is_connected(_on_settlement_restart_requested):
		settlement_panel.restart_requested.connect(_on_settlement_restart_requested)
	if settlement_panel.has_signal("upgrade_requested") and not settlement_panel.upgrade_requested.is_connected(_on_settlement_upgrade_requested):
		settlement_panel.upgrade_requested.connect(_on_settlement_upgrade_requested)

func _connect_player_health() -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health == null:
		return

	if player_health.has_signal("damaged"):
		player_health.damaged.connect(_on_player_damaged)
	if player_health.has_signal("healed"):
		player_health.healed.connect(_on_player_health_changed.unbind(1))
	if player_health.has_signal("died"):
		player_health.died.connect(_on_player_died)
	_update_player_health_hud(player_health)

func _on_player_health_changed() -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health != null:
		_update_player_health_hud(player_health)

func _on_player_damaged(amount: int) -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health == null:
		return
	_update_player_health_hud(player_health)
	if hud != null and hud.has_method("show_damage_feedback"):
		hud.show_damage_feedback(amount)
	_forward_weapon_trigger("on_player_hit", { "damage": amount })
	var heavy_threshold := int(
		ceil(float(player_health.get("max_health")) * 0.25)
	)
	if (
		amount >= heavy_threshold
		and enemy_director != null
		and enemy_director.has_method("notify_player_heavy_damage")
	):
		enemy_director.notify_player_heavy_damage()

func _on_player_died() -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health != null:
		_update_player_health_hud(player_health)
	record_player_defeat()

func _update_player_health_hud(player_health: Node) -> void:
	if hud != null and hud.has_method("set_health"):
		hud.set_health(int(player_health.get("current_health")), int(player_health.get("max_health")))

func _show_settlement_result(title: String) -> void:
	if settlement_panel != null and settlement_panel.has_method("show_result"):
		settlement_panel.show_result(title, settlement_rewards, run_summary)
	_refresh_settlement_upgrade_offer()

func _show_runtime_upgrade_feedback(upgrade: Dictionary) -> void:
	if hud == null or not hud.has_method("show_upgrade_feedback"):
		return
	var display_name := String(upgrade.get("display_name", upgrade.get("id", "Upgrade")))
	hud.show_upgrade_feedback(display_name)

func _refresh_settlement_upgrade_offer() -> Dictionary:
	if settlement_panel == null:
		return {}
	if not _ensure_database_loaded():
		return {}

	var save_data := _load_save_data()
	equipment_system.configure(database.get_equipment())
	var offers := _build_settlement_upgrade_offers(save_data)
	if offers.is_empty():
		return {}

	var first_offer: Dictionary = offers[0]
	if settlement_panel.has_method("show_upgrade_offer"):
		settlement_panel.show_upgrade_offer(
			first_offer.get("equipment_id", ""),
			first_offer.get("display_name", ""),
			int(first_offer.get("level", 1)),
			int(first_offer.get("cost", 0)),
			int(first_offer.get("total_materials", 0)),
			bool(first_offer.get("can_upgrade", false))
		)
	if settlement_panel.has_method("show_upgrade_offers"):
		settlement_panel.show_upgrade_offers(offers)
	return first_offer

func _show_settlement_upgrade_feedback(equipment_id: String, level: int) -> void:
	if settlement_panel == null or not settlement_panel.has_method("show_upgrade_feedback"):
		return
	var equipment_definition := _get_equipment_definition(equipment_id)
	var display_name := String(equipment_definition.get("display_name", equipment_id))
	settlement_panel.show_upgrade_feedback(display_name, level)

func _build_settlement_upgrade_offers(save_data: Dictionary) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var total_materials := int(save_data.get("materials", 0))
	var levels: Dictionary = save_data.get("equipment_levels", {})
	var unlocked: Array = save_data.get("unlocked_equipment", [])

	for equipment_id in SETTLEMENT_UPGRADE_EQUIPMENT_IDS:
		if not unlocked.has(equipment_id):
			continue
		var equipment_definition := _get_equipment_definition(equipment_id)
		if equipment_definition.is_empty():
			continue
		var level: int = max(1, int(levels.get(equipment_id, 1)))
		offers.append({
			"equipment_id": equipment_id,
			"display_name": equipment_definition.get("display_name", equipment_id),
			"level": level,
			"cost": equipment_system.get_upgrade_cost(equipment_id, save_data),
			"total_materials": total_materials,
			"can_upgrade": equipment_system.can_upgrade(equipment_id, save_data),
			"stat_summary": _build_equipment_stat_summary(equipment_definition),
			"route_label": _get_equipment_route_label(equipment_id),
			"route_color": _get_equipment_route_color(equipment_id),
		})
	return offers

func _get_equipment_definition(equipment_id: String) -> Dictionary:
	for definition in database.get_equipment():
		if definition.get("id", "") == equipment_id:
			return definition
	return {}

func _get_equipment_route_label(equipment_id: String) -> String:
	match equipment_id:
		"talisman_robe":
			return "生命"
		"cloudstep_boots":
			return "移速"
		"bronze_gear_core":
			return "冷却"
		"jade_compass":
			return "聚灵"
	return ""

func _get_equipment_route_color(equipment_id: String) -> String:
	match equipment_id:
		"talisman_robe":
			return "#ff8a8a"
		"cloudstep_boots":
			return "#8fd6ff"
		"bronze_gear_core":
			return "#ffd166"
		"jade_compass":
			return "#8df0a9"
	return "#ffffff"

func _build_equipment_stat_summary(equipment_definition: Dictionary) -> String:
	var modifiers: Dictionary = equipment_definition.get("stat_modifiers", {})
	var parts: Array[String] = []
	for stat in modifiers.keys():
		var value := float(modifiers[stat])
		match String(stat):
			"max_health":
				parts.append("生命 %s" % _format_signed_stat_value(value, false))
			"move_speed":
				parts.append("移速 %s" % _format_signed_stat_value(value, false))
			"weapon_cooldown_multiplier":
				parts.append("冷却 %s" % _format_signed_stat_value(value, true))
			"pickup_radius":
				parts.append("拾取 %s" % _format_signed_stat_value(value, false))
			"material_gain":
				parts.append("灵石 %s" % _format_signed_stat_value(value, true))
			"weapon_damage_multiplier":
				parts.append("伤害 %s" % _format_signed_stat_value(value, true))
			"control_duration":
				parts.append("控制 %s" % _format_signed_stat_value(value, true))
	return _join_summary_parts(parts)

func _format_signed_stat_value(value: float, as_percent: bool) -> String:
	var scale := 100.0 if as_percent else 1.0
	var amount := int(round(value * scale))
	var prefix := "+" if amount > 0 else ""
	var suffix := "%" if as_percent else ""
	return "%s%d%s" % [prefix, amount, suffix]

func _join_summary_parts(parts: Array[String]) -> String:
	var text := ""
	for part in parts:
		if text != "":
			text += "，"
		text += part
	return text

func _persist_settlement_rewards() -> bool:
	if settlement_saved:
		return false
	if save_system == null or not save_system.has_method("load_game") or not save_system.has_method("save_game"):
		return false

	var save_data = save_system.load_game()
	if typeof(save_data) != TYPE_DICTIONARY:
		save_data = {}

	var earned_materials := int(settlement_rewards.get("materials", 0))
	save_data["materials"] = int(save_data.get("materials", 0)) + earned_materials
	settlement_saved = bool(save_system.save_game(save_data))
	return settlement_saved

func _on_settlement_restart_requested() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	tree.paused = false
	tree.reload_current_scene()

func _on_settlement_upgrade_requested(equipment_id: String) -> void:
	upgrade_settlement_equipment(equipment_id)
