extends RefCounted
class_name EnemyActionState

const LOCOMOTION := "locomotion"
const WINDUP := "windup"
const ACTIVE := "active"
const RECOVERY := "recovery"
const DEAD := "dead"

var state: String = LOCOMOTION
var remaining: float = 0.0
var active_duration: float = 0.1
var recovery_duration: float = 0.4

func reset() -> void:
	state = LOCOMOTION
	remaining = 0.0

func start_attack(windup: float, active: float, recovery: float) -> bool:
	if state != LOCOMOTION:
		return false
	state = WINDUP
	remaining = maxf(0.001, windup)
	active_duration = maxf(0.001, active)
	recovery_duration = maxf(0.001, recovery)
	return true

func tick(delta: float, time_scale: float = 1.0) -> Array[String]:
	var transitions: Array[String] = []
	if state == LOCOMOTION or state == DEAD:
		return transitions

	remaining -= maxf(0.0, delta) * clampf(time_scale, 0.0, 1.0)
	while remaining <= 0.0 and state != LOCOMOTION and state != DEAD:
		var overflow := -remaining
		match state:
			WINDUP:
				state = ACTIVE
				remaining = active_duration - overflow
			ACTIVE:
				state = RECOVERY
				remaining = recovery_duration - overflow
			RECOVERY:
				state = LOCOMOTION
				remaining = 0.0
		transitions.append(state)
	return transitions

func is_damage_active() -> bool:
	return state == ACTIVE

func can_move() -> bool:
	return state == LOCOMOTION

func mark_dead() -> void:
	state = DEAD
	remaining = 0.0
