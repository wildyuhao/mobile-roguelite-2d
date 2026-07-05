extends RefCounted
class_name SettlementSystem

const MATERIALS_PER_ENEMY := 1
const BOSS_CLEAR_BONUS := 18

func calculate_rewards(run_summary: Dictionary) -> Dictionary:
	var defeated_enemies := int(run_summary.get("defeated_enemies", 0))
	var base_materials := int(run_summary.get("base_materials", 0))
	var boss_defeated := bool(run_summary.get("boss_defeated", false))
	var materials := base_materials + defeated_enemies * MATERIALS_PER_ENEMY
	if boss_defeated:
		materials += BOSS_CLEAR_BONUS

	return {
		"materials": materials,
		"boss_defeated": boss_defeated,
		"defeated_enemies": defeated_enemies
	}
