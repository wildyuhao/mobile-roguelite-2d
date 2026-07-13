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
	var rounded_experience := int(round(base * failure_ratio))
	var minimum_experience := int(ceil(base * 0.35))
	var maximum_experience := int(floor(base * 0.55))
	return clampi(rounded_experience, minimum_experience, maximum_experience)

func apply_experience(characters_state: Dictionary, character_id: String, amount: int) -> Dictionary:
	var updated_state: Dictionary = characters_state.duplicate(true)
	var unlocked_ids_value = updated_state.get("unlocked_ids", [])
	if (
		character_id.is_empty()
		or amount <= 0
		or typeof(unlocked_ids_value) != TYPE_ARRAY
		or not Array(unlocked_ids_value).has(character_id)
	):
		return updated_state

	var experience_by_character: Dictionary = {}
	if typeof(updated_state.get("mastery_experience")) == TYPE_DICTIONARY:
		experience_by_character = Dictionary(updated_state["mastery_experience"]).duplicate(true)
	var levels_by_character: Dictionary = {}
	if typeof(updated_state.get("mastery_levels")) == TYPE_DICTIONARY:
		levels_by_character = Dictionary(updated_state["mastery_levels"]).duplicate(true)
	var experience := maxi(0, int(experience_by_character.get(character_id, 0))) + amount
	experience_by_character[character_id] = experience
	levels_by_character[character_id] = get_level_for_experience(experience)
	updated_state["mastery_experience"] = experience_by_character
	updated_state["mastery_levels"] = levels_by_character
	return updated_state
