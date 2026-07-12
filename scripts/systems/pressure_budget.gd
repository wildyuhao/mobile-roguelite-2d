extends RefCounted
class_name PressureBudget

const OPENING_BUDGET := 14
const BUDGET_PER_MINUTE := 3
const MAX_BUDGET := 32
const MAX_ADJUSTMENT := 0.15
const HEAVY_DAMAGE_RECOVERY := 8.0
const MAX_RANGED_RATIO := 0.35
const MAX_CONTROL := 2

var performance_factor: float = 0.0
var recovery_remaining: float = 0.0

func set_performance_factor(value: float) -> void:
	performance_factor = clampf(value, -1.0, 1.0)

func notify_heavy_damage() -> void:
	recovery_remaining = HEAVY_DAMAGE_RECOVERY

func tick(delta: float) -> void:
	recovery_remaining = maxf(
		0.0,
		recovery_remaining - maxf(0.0, delta)
	)

func get_budget(elapsed: float) -> int:
	var minute_steps := int(floor(maxf(0.0, elapsed) / 60.0))
	var baseline := mini(
		MAX_BUDGET,
		OPENING_BUDGET + minute_steps * BUDGET_PER_MINUTE
	)
	var factor := (
		minf(0.0, performance_factor)
		if recovery_remaining > 0.0
		else performance_factor
	)
	return maxi(
		1,
		int(round(baseline * (1.0 + factor * MAX_ADJUSTMENT)))
	)

func can_schedule(
	card: Dictionary,
	enemy_definitions: Dictionary,
	active_counts: Dictionary,
	active_total: int,
	max_active: int
) -> bool:
	var planned_total := 0
	var planned_ranged := 0
	var planned_control := 0
	for group in card.get("groups", []):
		var count := int(group.get("count", 0))
		var definition: Dictionary = enemy_definitions.get(
			String(group.get("enemy_id", "")),
			{}
		)
		var role := String(definition.get("role", "swarm"))
		planned_total += count
		if role == "ranged":
			planned_ranged += count
		elif role == "control":
			planned_control += count

	if active_total + planned_total > max_active:
		return false
	var combined_total := active_total + planned_total
	var combined_ranged := int(active_counts.get("ranged", 0)) + planned_ranged
	if (
		combined_total > 0
		and float(combined_ranged) / float(combined_total) > MAX_RANGED_RATIO
	):
		return false
	return int(active_counts.get("control", 0)) + planned_control <= MAX_CONTROL
