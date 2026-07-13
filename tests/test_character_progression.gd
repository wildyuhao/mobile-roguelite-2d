extends RefCounted

const PROGRESSION_PATH := "res://scripts/systems/character_progression.gd"
const THRESHOLDS := [0, 100, 240, 430, 680, 990, 1360, 1790, 2280, 2830]
const MISSION_TYPES := ["survival", "seal", "hunt", "mutation", "boss"]
const BASE_EXPERIENCE := {
	"survival": 100,
	"seal": 110,
	"hunt": 120,
	"mutation": 140,
	"boss": 200,
}

func run(runner) -> void:
	if not ResourceLoader.exists(PROGRESSION_PATH):
		runner.assert_true(false, "character progression script should exist")
		return

	var progression_script = load(PROGRESSION_PATH)
	if progression_script == null or not progression_script.can_instantiate():
		runner.assert_true(false, "character progression script should load")
		return

	var progression = progression_script.new()
	_test_thresholds_and_bounds(runner, progression)
	_test_mission_experience(runner, progression)
	_test_character_independence(runner, progression)

func _test_thresholds_and_bounds(runner, progression) -> void:
	for level in range(1, 11):
		runner.assert_eq(
			progression.get_level_for_experience(THRESHOLDS[level - 1]),
			level,
			"threshold %d should produce level %d" % [level, level],
		)
	runner.assert_eq(progression.get_level_for_experience(-1), 1, "negative experience should stay at level 1")
	runner.assert_eq(progression.get_level_for_experience(THRESHOLDS[-1] - 1), 9, "level 10 should require its threshold")
	runner.assert_eq(progression.get_level_for_experience(999999), 10, "experience should cap at level 10")

func _test_mission_experience(runner, progression) -> void:
	for mission_type in MISSION_TYPES:
		var base: int = BASE_EXPERIENCE[mission_type]
		var victory: int = progression.calculate_mission_experience(mission_type, true, 1.0, false)
		var failure_at_zero: int = progression.calculate_mission_experience(mission_type, false, 0.0, false)
		var failure_at_full: int = progression.calculate_mission_experience(mission_type, false, 1.0, false)
		runner.assert_eq(victory, base, "%s victory should award its base XP" % mission_type)
		runner.assert_true(float(failure_at_zero) / float(victory) >= 0.35, "%s failure floor should be at least 35%%" % mission_type)
		runner.assert_true(float(failure_at_zero) / float(victory) <= 0.55, "%s failure floor should be at most 55%%" % mission_type)
		runner.assert_true(float(failure_at_full) / float(victory) >= 0.35, "%s failure ceiling should be at least 35%%" % mission_type)
		runner.assert_true(float(failure_at_full) / float(victory) <= 0.55, "%s failure ceiling should be at most 55%%" % mission_type)
		runner.assert_eq(failure_at_zero, maxi(int(ceil(base * 0.35)), int(round(base * 0.35))), "%s progress 0 should use the bounded 35%% XP result" % mission_type)
		runner.assert_eq(failure_at_full, mini(int(floor(base * 0.55)), int(round(base * 0.55))), "%s progress 1 should use the bounded 55%% XP result" % mission_type)
		runner.assert_eq(
			progression.calculate_mission_experience(mission_type, false, 0.5, true),
			progression.calculate_mission_experience(mission_type, false, 0.5, false),
			"%s failure should receive no first-completion bonus" % mission_type,
		)

	runner.assert_eq(progression.calculate_mission_experience("survival", true, 1.0, true), 125, "first survival victory should add 25%% bonus")
	runner.assert_eq(progression.calculate_mission_experience("survival", true, 1.0, false), 100, "repeat survival victory should omit bonus")
	runner.assert_eq(progression.calculate_mission_experience("survival", false, 1.0, true), 55, "failed first completion should omit bonus")
	runner.assert_eq(progression.calculate_mission_experience("unknown", true, 1.0, false), 0, "unknown mission type should award no XP")

func _test_character_independence(runner, progression) -> void:
	var initial := {
		"unlocked_ids": ["azure", "crimson", "ember"],
		"mastery_experience": {
			"azure": 90,
			"crimson": 240,
			"ember": -40,
			"locked": 100,
		},
		"mastery_levels": {
			"azure": 1,
			"crimson": 3,
			"ember": 1,
			"locked": 2,
		},
		"selected_id": "azure",
		"starting_loadouts": {"azure": {"weapon": "crossbow"}},
	}
	var updated: Dictionary = progression.apply_experience(initial, "azure", 20)
	runner.assert_eq(updated["mastery_experience"]["azure"], 110, "selected character should receive cumulative XP")
	runner.assert_eq(updated["mastery_levels"]["azure"], 2, "selected character level should be derived from cumulative XP")
	runner.assert_eq(updated["mastery_experience"]["crimson"], 240, "other character XP should remain independent")
	runner.assert_eq(updated["mastery_levels"]["crimson"], 3, "other character levels should remain independent")
	runner.assert_eq(updated["selected_id"], "azure", "selected character metadata should be preserved")
	runner.assert_eq(updated["starting_loadouts"], initial["starting_loadouts"], "starting loadouts should be preserved")
	runner.assert_eq(initial["mastery_experience"]["azure"], 90, "input state should not be mutated")
	var save := {"characters": initial.duplicate(true)}
	save["characters"] = progression.apply_experience(save["characters"], "azure", 20)
	runner.assert_eq(save["characters"], updated, "progression output should assign directly back to save characters")
	var normalized: Dictionary = progression.apply_experience(initial, "ember", 50)
	runner.assert_eq(normalized["mastery_experience"]["ember"], 50, "negative mastery XP should normalize to zero before adding")
	runner.assert_eq(normalized["mastery_levels"]["ember"], 1, "normalized mastery XP should derive the correct level")
	runner.assert_true(normalized["mastery_experience"]["ember"] >= 0, "mastery XP should never remain negative")
	runner.assert_eq(progression.apply_experience(initial, "", 20), initial, "empty character ID should leave a duplicate unchanged")
	runner.assert_eq(progression.apply_experience(initial, "locked", 20), initial, "locked character ID should leave a duplicate unchanged")
	runner.assert_eq(progression.apply_experience(initial, "missing", 20), initial, "unknown character ID should leave a duplicate unchanged")
	runner.assert_eq(progression.apply_experience(initial, "azure", 0), initial, "zero XP should leave a duplicate unchanged")
	runner.assert_eq(progression.apply_experience(initial, "azure", -5), initial, "negative XP should leave a duplicate unchanged")
	var rejected: Dictionary = progression.apply_experience(initial, "", 20)
	rejected["mastery_experience"]["azure"] = 999
	runner.assert_eq(initial["mastery_experience"]["azure"], 90, "rejected updates should still return a deep duplicate")
