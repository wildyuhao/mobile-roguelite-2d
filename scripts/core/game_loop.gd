extends Node2D
class_name GameLoop

const GameConstantsScript = preload("res://scripts/core/constants.gd")
const GameDatabaseScript = preload("res://scripts/data/game_database.gd")
const UpgradeSystemScript = preload("res://scripts/systems/upgrade_system.gd")

@export var projectile_scene: PackedScene

@onready var player: Node2D = $Player
@onready var enemy_director: Node = $EnemyDirector
@onready var experience_system: Node = $ExperienceSystem
@onready var weapon_system: Node = $WeaponSystem
@onready var hud: Node = $HUD
@onready var upgrade_choice_panel: Node = $UpgradeChoicePanel

var database = GameDatabaseScript.new()
var upgrade_system = UpgradeSystemScript.new()
var runtime_state := {
	"owned_weapons": { "flying_sword": 1 },
	"upgrade_stacks": {},
}
var run_time: float = 0.0

func _ready() -> void:
	var loaded = database.load_all()
	assert(loaded, "Game database failed to load: %s" % str(database.errors))

	upgrade_system.configure(database.get_upgrades())
	weapon_system.add_weapon(database.get_weapon("flying_sword"))
	enemy_director.configure(database, player)
	experience_system.level_up.connect(_on_level_up)
	experience_system.experience_changed.connect(hud.set_experience)
	upgrade_choice_panel.upgrade_selected.connect(_on_upgrade_selected)
	hud.set_level(experience_system.level)
	hud.set_experience(experience_system.current_experience, experience_system.get_required_experience())

func _process(delta: float) -> void:
	run_time += delta
	hud.set_run_time(run_time)

	var fire_events = weapon_system.tick(delta)
	for event in fire_events:
		_spawn_projectiles(event)

func _spawn_projectiles(event: Dictionary) -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstantsScript.ENEMY_GROUP)
	if enemies.is_empty() or projectile_scene == null:
		return

	var target = enemies[0] as Node2D
	var direction: Vector2 = player.global_position.direction_to(target.global_position)
	var count := int(event.get("projectile_count", 1))
	for index in range(count):
		var projectile = projectile_scene.instantiate()
		add_child(projectile)
		projectile.global_position = player.global_position
		var spread := deg_to_rad(8.0 * (index - (count - 1) / 2.0))
		projectile.configure(direction.rotated(spread), float(event["projectile_speed"]), int(event["damage"]))

func _on_level_up(new_level: int) -> void:
	hud.set_level(new_level)
	get_tree().paused = true
	var choices: Array[Dictionary] = upgrade_system.get_choices(runtime_state, 3)
	upgrade_choice_panel.show_choices(choices)

func _on_upgrade_selected(upgrade: Dictionary) -> void:
	upgrade_system.apply_upgrade(runtime_state, upgrade)
	if upgrade.get("kind", "") == "weapon_level":
		weapon_system.level_weapon(upgrade.get("weapon_id", ""))
	get_tree().paused = false
