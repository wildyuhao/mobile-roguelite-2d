extends CharacterBody2D
class_name EnemyAgent

signal defeated(payload: Dictionary)
signal release_requested(node: Node)
signal ranged_attack_requested(payload: Dictionary)

const GameConstantsScript = preload("res://scripts/core/constants.gd")
const EnemyActionStateScript = preload("res://scripts/systems/enemy_action_state.gd")
const DEFAULT_MOVE_SPEED := 110.0
const DEFAULT_CHARGE_SPEED := 240.0
const DEFAULT_PREFERRED_RANGE := 300.0
const DEFAULT_CHARGE_TRIGGER_RANGE := 340.0
const DEFAULT_RANGED_ATTACK_RANGE := 380.0
const DEFAULT_PROJECTILE_SPEED := 330.0
const DEFAULT_PROJECTILE_LIFETIME := 2.4
const DEFAULT_PROJECTILE_DAMAGE := 8
const DEFAULT_PROJECTILE_RADIUS := 12.0
const PROJECTILE_SPAWN_PADDING := 4.0
const DEFAULT_ATTACK_WINDUP := 0.28
const DEFAULT_ATTACK_ACTIVE := 0.10
const DEFAULT_ATTACK_RECOVERY := 0.48
const DEFAULT_CONTACT_DAMAGE := 8
const DEFAULT_CONTACT_REACH_PADDING := 4.0
const DEFAULT_EXPERIENCE_VALUE := 1
const DEFAULT_MATERIAL_VALUE := 1

@export var move_speed: float = 110.0
@export var charge_speed: float = 240.0
@export var preferred_range: float = 300.0
@export var charge_trigger_range: float = 340.0
@export var ranged_attack_range: float = 380.0
@export var projectile_speed: float = 330.0
@export var projectile_lifetime: float = 2.4
@export var projectile_damage: int = 8
@export var attack_windup: float = 0.28
@export var attack_active: float = 0.10
@export var attack_recovery: float = 0.48
@export var contact_damage: int = 8
@export var contact_reach_padding: float = DEFAULT_CONTACT_REACH_PADDING
@export var experience_value: int = 1
@export var material_value: int = 1
@export var is_boss: bool = false

@onready var health: Node = $HealthComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_feedback: Node = get_node_or_null("HitFeedback")
@onready var status_controller: Node = get_node_or_null("StatusController")
@onready var ranged_aim_line: Line2D = get_node_or_null("RangedAimLine")
@onready var ranged_muzzle: Sprite2D = get_node_or_null("RangedMuzzle")
@onready var ranged_aim_sigil: Sprite2D = get_node_or_null("RangedAimSigil")
@onready var charge_warning_lane: Line2D = get_node_or_null("ChargeWarningLane")
@onready var charge_warning_core: Line2D = get_node_or_null("ChargeWarningCore")
@onready var charge_warning_sigil: Sprite2D = get_node_or_null("ChargeWarningSigil")
@onready var charge_trail: Sprite2D = get_node_or_null("ChargeTrail")
@onready var charge_dust: Sprite2D = get_node_or_null("ChargeDust")

var target: Node2D
var behavior: String = "chase"
var action_state = EnemyActionStateScript.new()
var locked_action_direction: Vector2 = Vector2.RIGHT
var damage_applied_this_action: bool = false
var ranged_attack_emitted_this_action: bool = false
var pool_active: bool = true

func configure(definition: Dictionary, new_target: Node2D) -> void:
	if health == null:
		health = get_node_or_null("HealthComponent")
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if status_controller == null:
		status_controller = get_node_or_null("StatusController")
	if ranged_aim_line == null:
		ranged_aim_line = get_node_or_null("RangedAimLine") as Line2D
	if ranged_muzzle == null:
		ranged_muzzle = get_node_or_null("RangedMuzzle") as Sprite2D
	if ranged_aim_sigil == null:
		ranged_aim_sigil = get_node_or_null("RangedAimSigil") as Sprite2D
	if charge_warning_lane == null:
		charge_warning_lane = get_node_or_null("ChargeWarningLane") as Line2D
	if charge_warning_core == null:
		charge_warning_core = get_node_or_null("ChargeWarningCore") as Line2D
	if charge_warning_sigil == null:
		charge_warning_sigil = get_node_or_null("ChargeWarningSigil") as Sprite2D
	if charge_trail == null:
		charge_trail = get_node_or_null("ChargeTrail") as Sprite2D
	if charge_dust == null:
		charge_dust = get_node_or_null("ChargeDust") as Sprite2D
	_reset_definition_defaults()
	target = new_target
	behavior = definition.get("behavior", "chase")
	action_state.reset()
	locked_action_direction = Vector2.RIGHT
	damage_applied_this_action = false
	ranged_attack_emitted_this_action = false
	charge_trigger_range = float(definition.get("charge_trigger_range", charge_trigger_range))
	ranged_attack_range = float(definition.get("ranged_attack_range", ranged_attack_range))
	projectile_speed = float(definition.get("projectile_speed", projectile_speed))
	projectile_lifetime = float(definition.get("projectile_lifetime", projectile_lifetime))
	projectile_damage = int(definition.get("projectile_damage", projectile_damage))
	attack_windup = float(definition.get("attack_windup", attack_windup))
	attack_active = float(definition.get("attack_active", attack_active))
	attack_recovery = float(definition.get("attack_recovery", attack_recovery))
	move_speed = float(definition.get("move_speed", move_speed))
	charge_speed = float(definition.get("charge_speed", charge_speed))
	preferred_range = float(definition.get("preferred_range", preferred_range))
	contact_damage = int(definition.get("contact_damage", contact_damage))
	contact_reach_padding = float(
		definition.get("contact_reach_padding", contact_reach_padding)
	)
	experience_value = int(definition.get("experience_value", experience_value))
	material_value = int(definition.get("material_value", material_value))
	is_boss = definition.get("behavior", "") == "boss" or bool(definition.get("is_boss", false))
	if status_controller != null and status_controller.has_method("configure"):
		status_controller.configure(is_boss)
	if health != null:
		health.configure(int(definition.get("max_health", 24)))
	_configure_sprite(definition)
	_configure_collision(definition)
	_reset_ranged_visuals()
	_reset_charge_visuals()

func _reset_definition_defaults() -> void:
	behavior = "chase"
	move_speed = DEFAULT_MOVE_SPEED
	charge_speed = DEFAULT_CHARGE_SPEED
	preferred_range = DEFAULT_PREFERRED_RANGE
	charge_trigger_range = DEFAULT_CHARGE_TRIGGER_RANGE
	ranged_attack_range = DEFAULT_RANGED_ATTACK_RANGE
	projectile_speed = DEFAULT_PROJECTILE_SPEED
	projectile_lifetime = DEFAULT_PROJECTILE_LIFETIME
	projectile_damage = DEFAULT_PROJECTILE_DAMAGE
	attack_windup = DEFAULT_ATTACK_WINDUP
	attack_active = DEFAULT_ATTACK_ACTIVE
	attack_recovery = DEFAULT_ATTACK_RECOVERY
	contact_damage = DEFAULT_CONTACT_DAMAGE
	contact_reach_padding = DEFAULT_CONTACT_REACH_PADDING
	experience_value = DEFAULT_EXPERIENCE_VALUE
	material_value = DEFAULT_MATERIAL_VALUE
	is_boss = false

func _ready() -> void:
	add_to_group(GameConstantsScript.ENEMY_GROUP)
	_connect_health_signals()

func _physics_process(delta: float) -> void:
	if not pool_active:
		return
	velocity = calculate_action_velocity(delta)
	move_and_slide()

func calculate_action_velocity(delta: float) -> Vector2:
	var action_time_scale := _get_action_time_scale()
	var movement_multiplier := _get_movement_multiplier()
	if status_controller != null and status_controller.has_method("tick_statuses"):
		status_controller.tick_statuses(delta)
	if behavior == "ranged" and action_state.state == EnemyActionStateScript.WINDUP:
		_update_ranged_lock()
	var transitions := action_state.tick(delta, action_time_scale)
	if transitions.has(EnemyActionStateScript.ACTIVE):
		damage_applied_this_action = false
		if behavior == "ranged":
			_emit_ranged_attack()

	var result := Vector2.ZERO
	if action_state.state == EnemyActionStateScript.ACTIVE:
		if behavior != "ranged" and action_time_scale > 0.0:
			_try_action_damage()
		if behavior == "charge":
			result = locked_action_direction * charge_speed
	elif action_state.state == EnemyActionStateScript.LOCOMOTION:
		if behavior == "charge":
			result = _calculate_charge_velocity()
		elif behavior == "ranged":
			result = calculate_desired_velocity(delta)
			if (
				result == Vector2.ZERO
				and _is_target_in_ranged_attack_range()
				and _can_start_action(true)
			):
				_update_ranged_lock()
				ranged_attack_emitted_this_action = false
				action_state.start_attack(attack_windup, attack_active, attack_recovery)
				result = Vector2.ZERO
		else:
			result = calculate_desired_velocity(delta)
			if _is_target_in_contact_range() and _can_start_action(_is_special_behavior()):
				locked_action_direction = global_position.direction_to(target.global_position)
				action_state.start_attack(attack_windup, attack_active, attack_recovery)
				result = Vector2.ZERO
	_update_action_visual()
	return result * movement_multiplier

func calculate_desired_velocity(_delta: float) -> Vector2:
	if target == null:
		return Vector2.ZERO

	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return Vector2.ZERO

	match behavior:
		"charge":
			return to_target.normalized() * move_speed
		"ranged":
			var distance := to_target.length()
			var tolerance := 24.0
			if distance < preferred_range - tolerance:
				return -to_target.normalized() * move_speed
			if distance > preferred_range + tolerance:
				return to_target.normalized() * move_speed
			return Vector2.ZERO
		_:
			return to_target.normalized() * move_speed

func _calculate_charge_velocity() -> Vector2:
	if target == null:
		return Vector2.ZERO
	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return Vector2.ZERO
	if to_target.length() <= charge_trigger_range and _can_start_action(true):
		locked_action_direction = to_target.normalized()
		damage_applied_this_action = false
		action_state.start_attack(attack_windup, attack_active, attack_recovery)
		return Vector2.ZERO
	return to_target.normalized() * move_speed

func _is_target_in_contact_range() -> bool:
	if target == null:
		return false
	return (
		global_position.distance_to(target.global_position)
		<= get_contact_attack_range(target)
	)

func get_contact_attack_range(target_node: Node2D) -> float:
	if target_node == null:
		return 0.0
	return (
		get_contact_radius()
		+ _get_target_contact_radius(target_node)
		+ maxf(0.0, contact_reach_padding)
	)

func _try_action_damage() -> void:
	if damage_applied_this_action:
		return
	if try_apply_contact_damage():
		damage_applied_this_action = true

func _update_action_visual() -> void:
	if sprite != null:
		match action_state.state:
			EnemyActionStateScript.WINDUP:
				sprite.modulate = Color(1.0, 0.65, 0.25)
			EnemyActionStateScript.ACTIVE:
				sprite.modulate = Color(1.0, 0.3, 0.3)
			EnemyActionStateScript.RECOVERY:
				sprite.modulate = Color(0.72, 0.72, 0.72)
			_:
				sprite.modulate = Color.WHITE
	_update_ranged_telegraph_visuals()
	_update_charge_telegraph_visuals()

func _is_target_in_ranged_attack_range() -> bool:
	return (
		target != null
		and global_position.distance_to(target.global_position) <= ranged_attack_range
	)

func _update_ranged_lock() -> void:
	if target == null:
		return
	var next_direction := global_position.direction_to(target.global_position)
	if next_direction != Vector2.ZERO:
		locked_action_direction = next_direction

func _emit_ranged_attack() -> void:
	if ranged_attack_emitted_this_action:
		return
	ranged_attack_emitted_this_action = true
	var direction := locked_action_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	ranged_attack_requested.emit({
		"origin": global_position + direction * (
			get_contact_radius() + DEFAULT_PROJECTILE_RADIUS + PROJECTILE_SPAWN_PADDING
		),
		"direction": direction,
		"damage": projectile_damage,
		"speed": projectile_speed,
		"lifetime": projectile_lifetime,
	})

func _update_ranged_telegraph_visuals() -> void:
	var show_aim: bool = behavior == "ranged" and action_state.state == EnemyActionStateScript.WINDUP
	var show_muzzle: bool = behavior == "ranged" and action_state.state == EnemyActionStateScript.ACTIVE
	var aim_length := ranged_attack_range
	if target != null:
		aim_length = minf(aim_length, global_position.distance_to(target.global_position))
	if ranged_aim_line != null:
		ranged_aim_line.visible = show_aim
		ranged_aim_line.points = PackedVector2Array([
			Vector2.ZERO,
			locked_action_direction * aim_length,
		])
	if ranged_aim_sigil != null:
		ranged_aim_sigil.visible = show_aim
		ranged_aim_sigil.position = locked_action_direction * aim_length
		ranged_aim_sigil.rotation = locked_action_direction.angle()
	if ranged_muzzle != null:
		ranged_muzzle.visible = show_muzzle
		ranged_muzzle.position = locked_action_direction * (
			get_contact_radius() + DEFAULT_PROJECTILE_RADIUS + PROJECTILE_SPAWN_PADDING
		)
		ranged_muzzle.rotation = locked_action_direction.angle()

func _reset_ranged_visuals() -> void:
	if ranged_aim_line != null:
		ranged_aim_line.visible = false
	if ranged_aim_sigil != null:
		ranged_aim_sigil.visible = false
	if ranged_muzzle != null:
		ranged_muzzle.visible = false

func _update_charge_telegraph_visuals() -> void:
	var show_warning: bool = behavior == "charge" and action_state.state == EnemyActionStateScript.WINDUP
	var show_trail: bool = behavior == "charge" and action_state.state == EnemyActionStateScript.ACTIVE
	var show_dust: bool = behavior == "charge" and action_state.state == EnemyActionStateScript.RECOVERY
	var direction := locked_action_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var charge_distance := maxf(1.0, charge_speed * attack_active)
	for line in [charge_warning_lane, charge_warning_core]:
		if line == null:
			continue
		line.visible = show_warning
		line.points = PackedVector2Array([Vector2.ZERO, direction * charge_distance])
	if charge_warning_sigil != null:
		charge_warning_sigil.visible = show_warning
		charge_warning_sigil.position = direction * charge_distance
		charge_warning_sigil.rotation = direction.angle()
	if charge_trail != null:
		charge_trail.visible = show_trail
		charge_trail.position = -direction * 32.0
		charge_trail.rotation = direction.angle()
	if charge_dust != null:
		charge_dust.visible = show_dust
		charge_dust.rotation = direction.angle()

func _reset_charge_visuals() -> void:
	for visual in [
		charge_warning_lane,
		charge_warning_core,
		charge_warning_sigil,
		charge_trail,
		charge_dust,
	]:
		if visual != null:
			visual.visible = false

func _on_died() -> void:
	action_state.mark_dead()
	if status_controller != null and status_controller.has_method("clear_all"):
		status_controller.clear_all()
	_reset_hit_feedback()
	_reset_ranged_visuals()
	_reset_charge_visuals()
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	defeated.emit(get_defeat_payload())
	_release_or_free()

func activate_from_pool() -> void:
	pool_active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	velocity = Vector2.ZERO
	action_state.reset()
	locked_action_direction = Vector2.RIGHT
	damage_applied_this_action = false
	ranged_attack_emitted_this_action = false
	_clear_runtime_metadata()
	if status_controller != null and status_controller.has_method("clear_all"):
		status_controller.clear_all()
	_reset_hit_feedback()
	_reset_ranged_visuals()
	_reset_charge_visuals()
	if not is_in_group(GameConstantsScript.ENEMY_GROUP):
		add_to_group(GameConstantsScript.ENEMY_GROUP)
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite != null:
		sprite.modulate = Color.WHITE

func deactivate_for_pool() -> void:
	_reset_hit_feedback()
	begin_pool_release()
	process_mode = Node.PROCESS_MODE_DISABLED
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

func begin_pool_release() -> void:
	pool_active = false
	target = null
	velocity = Vector2.ZERO
	action_state.mark_dead()
	damage_applied_this_action = false
	ranged_attack_emitted_this_action = false
	_clear_runtime_metadata()
	if status_controller != null and status_controller.has_method("clear_all"):
		status_controller.clear_all()
	_reset_ranged_visuals()
	_reset_charge_visuals()
	visible = false
	remove_from_group(GameConstantsScript.ENEMY_GROUP)

func is_pool_active() -> bool:
	return pool_active

func _release_or_free() -> void:
	begin_pool_release()
	if release_requested.get_connections().is_empty():
		queue_free()
	else:
		release_requested.emit(self)

func get_defeat_payload() -> Dictionary:
	return {
		"enemy_position": global_position,
		"experience_value": experience_value,
		"material_value": material_value,
		"is_boss": is_boss,
		"source_weapon_id": String(get_meta("last_weapon_id", "")),
	}

func _get_action_time_scale() -> float:
	if status_controller != null and status_controller.has_method("get_action_time_scale"):
		return float(status_controller.get_action_time_scale())
	return 1.0

func _get_movement_multiplier() -> float:
	if status_controller != null and status_controller.has_method("get_movement_multiplier"):
		return float(status_controller.get_movement_multiplier())
	return 1.0

func _can_start_action(is_special: bool) -> bool:
	if _get_action_time_scale() <= 0.0:
		return false
	if (
		is_special
		and status_controller != null
		and status_controller.has_method("can_start_special")
	):
		return bool(status_controller.can_start_special())
	return true

func _is_special_behavior() -> bool:
	return behavior in ["charge", "ranged", "summon", "support"]

func _clear_runtime_metadata() -> void:
	for metadata_key in ["encounter_id", "enemy_role", "last_weapon_id"]:
		if has_meta(metadata_key):
			remove_meta(metadata_key)

func _configure_sprite(definition: Dictionary) -> void:
	if sprite == null:
		return

	var sprite_path: String = definition.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)

	var sprite_scale := float(definition.get("sprite_scale", 0.0))
	if sprite_scale > 0.0:
		sprite.scale = Vector2(sprite_scale, sprite_scale)

func _configure_collision(definition: Dictionary) -> void:
	if collision_shape == null:
		return

	var collision_radius := float(definition.get("collision_radius", 0.0))
	if collision_radius <= 0.0:
		return

	var circle_shape: CircleShape2D
	if collision_shape.shape is CircleShape2D:
		circle_shape = (collision_shape.shape as CircleShape2D).duplicate()
	else:
		circle_shape = CircleShape2D.new()
	circle_shape.radius = collision_radius
	collision_shape.shape = circle_shape

func try_apply_contact_damage() -> bool:
	if target == null or not target.has_method("take_contact_damage"):
		return false
	if not target is Node2D:
		return false

	var target_node := target as Node2D
	if (
		global_position.distance_to(target_node.global_position)
		> get_contact_attack_range(target_node)
	):
		return false

	return bool(target_node.call("take_contact_damage", contact_damage))

func get_contact_radius() -> float:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		return (collision_shape.shape as CircleShape2D).radius
	return 16.0

func _get_target_contact_radius(target_node: Node2D) -> float:
	if target_node.has_method("get_contact_radius"):
		return float(target_node.call("get_contact_radius"))
	return 18.0

func _connect_health_signals() -> void:
	if health == null:
		return
	var damaged_callback := Callable(self, "_on_damaged")
	if health.has_signal("damaged") and not health.is_connected("damaged", damaged_callback):
		health.connect("damaged", damaged_callback)
	var died_callback := Callable(self, "_on_died")
	if health.has_signal("died") and not health.is_connected("died", died_callback):
		health.connect("died", died_callback)

func _on_damaged(amount: int) -> void:
	if not pool_active:
		return
	if hit_feedback != null and hit_feedback.has_method("play_hit"):
		hit_feedback.play_hit(amount, &"enemy")

func _reset_hit_feedback() -> void:
	if hit_feedback != null and hit_feedback.has_method("reset_feedback"):
		hit_feedback.reset_feedback()
