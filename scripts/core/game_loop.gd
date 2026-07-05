extends Node2D
class_name GameLoop

const GameConstantsScript = preload("res://scripts/core/constants.gd")
const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const UpgradeSystemScript = preload("res://scripts/systems/upgrade_system.gd")
const CombatResolverScript = preload("res://scripts/systems/combat_resolver.gd")
const SettlementSystemScript = preload("res://scripts/systems/settlement_system.gd")

@export var projectile_scene: PackedScene
@export var experience_pickup_scene: PackedScene

@onready var player: Node2D = $Player
@onready var enemy_director: Node = $EnemyDirector
@onready var experience_system: Node = $ExperienceSystem
@onready var weapon_system: Node = $WeaponSystem
@onready var hud: Node = $HUD
@onready var upgrade_choice_panel: Node = $UpgradeChoicePanel
@onready var virtual_joystick: Node = $VirtualJoystick/Stick
@onready var settlement_panel: Node = $SettlementPanel

var database = GameDatabaseScript.new()
var upgrade_system = UpgradeSystemScript.new()
var combat_resolver = CombatResolverScript.new()
var settlement_system = SettlementSystemScript.new()
var runtime_state := {
	"owned_weapons": { "flying_sword": 1 },
	"upgrade_stacks": {},
}
var run_summary := {
	"defeated_enemies": 0,
	"base_materials": 0,
	"boss_defeated": false,
}
var settlement_rewards := {}
var run_ended: bool = false
var run_time: float = 0.0

func _ready() -> void:
	var loaded = database.load_all()
	assert(loaded, "Game database failed to load: %s" % str(database.errors))

	upgrade_system.configure(database.get_upgrades())
	weapon_system.add_weapon(database.get_weapon("flying_sword"))
	enemy_director.enemy_spawned.connect(_on_enemy_spawned)
	enemy_director.configure(database, player)
	virtual_joystick.move_vector_changed.connect(player.set_external_move_vector)
	if settlement_panel != null and settlement_panel.has_signal("restart_requested"):
		settlement_panel.restart_requested.connect(_on_settlement_restart_requested)
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

	var fire_events = weapon_system.tick(delta)
	for event in fire_events:
		if event.get("weapon_type", "projectile") == "pulse":
			_apply_pulse_event(event)
		else:
			_spawn_projectiles(event)

func _spawn_projectiles(event: Dictionary) -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstantsScript.ENEMY_GROUP)
	if enemies.is_empty() or projectile_scene == null:
		return

	var target = combat_resolver.find_closest_enemy(player.global_position, enemies, float(event.get("range", 320.0)))
	if target == null:
		return

	var direction: Vector2 = player.global_position.direction_to(target.global_position)
	var count := int(event.get("projectile_count", 1))
	for projectile_direction in combat_resolver.build_spread_directions(direction, count, 8.0):
		var projectile = projectile_scene.instantiate()
		add_child(projectile)
		projectile.global_position = player.global_position
		if projectile.has_method("configure_from_event"):
			projectile.configure_from_event(projectile_direction, event)
		else:
			projectile.configure(projectile_direction, float(event["projectile_speed"]), int(event["damage"]))

func _apply_pulse_event(event: Dictionary) -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstantsScript.ENEMY_GROUP)
	var targets = combat_resolver.get_enemies_in_radius(player.global_position, enemies, float(event.get("range", 0.0)))
	for target in targets:
		_damage_enemy(target, int(event.get("damage", 1)))
		_apply_knockback(target, float(event.get("knockback", 0.0)))

func _damage_enemy(enemy: Node, amount: int) -> void:
	var target_health := enemy.get_node_or_null("HealthComponent")
	if target_health != null and target_health.has_method("take_damage"):
		target_health.take_damage(amount)

func _apply_knockback(enemy: Node2D, amount: float) -> void:
	if amount <= 0.0:
		return

	var direction := player.global_position.direction_to(enemy.global_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	enemy.global_position += direction * amount

func _on_level_up(new_level: int) -> void:
	hud.set_level(new_level)
	get_tree().paused = true
	var choices: Array[Dictionary] = upgrade_system.get_choices(runtime_state, 3)
	upgrade_choice_panel.show_choices(choices)

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	upgrade_system.apply_upgrade(runtime_state, upgrade)
	if upgrade.get("kind", "") == "weapon_level":
		weapon_system.level_weapon(upgrade.get("weapon_id", ""))
	elif upgrade.get("kind", "") == "weapon_unlock":
		var weapon_id: String = upgrade.get("weapon_id", "")
		if weapon_id != "" and not weapon_system.has_weapon(weapon_id):
			weapon_system.add_weapon(database.get_weapon(weapon_id))
	get_tree().paused = false

func _on_enemy_spawned(enemy: Node) -> void:
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated)

func _on_enemy_defeated(payload: Dictionary) -> void:
	record_enemy_defeat(payload)
	var enemy_position: Vector2 = payload.get("enemy_position", Vector2.ZERO)
	var experience_value := int(payload.get("experience_value", 0))
	if experience_pickup_scene == null:
		experience_system.add_experience(experience_value)
		return

	var pickup = experience_pickup_scene.instantiate()
	add_child(pickup)
	pickup.global_position = enemy_position
	pickup.configure(experience_value)
	pickup.collected.connect(experience_system.add_experience)

func record_enemy_defeat(payload: Dictionary) -> Dictionary:
	run_summary["defeated_enemies"] = int(run_summary.get("defeated_enemies", 0)) + 1
	run_summary["base_materials"] = int(run_summary.get("base_materials", 0)) + int(payload.get("material_value", 0))
	if bool(payload.get("is_boss", false)):
		run_summary["boss_defeated"] = true
		run_ended = true
		settlement_rewards = settlement_system.calculate_rewards(run_summary)
		_show_settlement_result("Boss Sealed")
	return run_summary

func record_player_defeat() -> Dictionary:
	if run_ended:
		return run_summary

	run_summary["boss_defeated"] = false
	run_summary["player_defeated"] = true
	run_ended = true
	settlement_rewards = settlement_system.calculate_rewards(run_summary)
	_show_settlement_result("Run Failed")
	if is_inside_tree():
		get_tree().paused = true
	return run_summary

func set_settlement_panel(panel: Node) -> void:
	settlement_panel = panel

func _connect_player_health() -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health == null:
		return

	if player_health.has_signal("damaged"):
		player_health.damaged.connect(_on_player_health_changed.unbind(1))
	if player_health.has_signal("healed"):
		player_health.healed.connect(_on_player_health_changed.unbind(1))
	if player_health.has_signal("died"):
		player_health.died.connect(_on_player_died)
	_update_player_health_hud(player_health)

func _on_player_health_changed() -> void:
	var player_health := player.get_node_or_null("HealthComponent")
	if player_health != null:
		_update_player_health_hud(player_health)

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

func _on_settlement_restart_requested() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	tree.paused = false
	tree.reload_current_scene()
