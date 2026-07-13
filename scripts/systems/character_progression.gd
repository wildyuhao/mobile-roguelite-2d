extends RefCounted

const EXPERIENCE_THRESHOLDS := [0, 100, 240, 430, 680, 990, 1360, 1790, 2280, 2830]
const BASE_EXPERIENCE := {
	"survival": 100,
	"seal": 110,
	"hunt": 120,
	"mutation": 140,
	"boss": 200,
}

func get_level_for_experience(experience: int) -> int:
	var level := 1
	for threshold in EXPERIENCE_THRESHOLDS:
		if experience >= threshold:
			level += 1
		else:
			break
	return clampi(level - 1, 1, 10)

func calculate_mission_experience(mission_type: String, victory: bool, progress_ratio: float, first_completion: bool) -> int:
	if not BASE_EXPERIENCE.has(mission_type):
		return 0

	var base: int = BASE_EXPERIENCE[mission_type]
	if victory:
		var first_completion_bonus := int(round(base * 0.25)) if first_completion else 0
		return base + first_completion_bonus

	var failure_ratio := lerpf(0.35, 0.55, clampf(progress_ratio, 0.0, 1.0))
	return int(round(base * failure_ratio))

func apply_experience(characters_state: Dictionary, character_id: String, amount: int) -> Dictionary:
	var updated_state: Dictionary = characters_state.duplicate(true)
	if character_id.is_empty() or amount <= 0 or not updated_state.has(character_id):
		return updated_state

	var character_state: Dictionary = Dictionary(updated_state[character_id]).duplicate(true)
	var experience := int(character_state.get("experience", 0)) + amount
	character_state["experience"] = experience
	character_state["level"] = get_level_for_experience(experience)
	updated_state[character_id] = character_state
	return updated_state

