extends RefCounted

const CampaignProgressionScript = preload("res://scripts/systems/campaign_progression.gd")

func run(runner) -> void:
	var system = CampaignProgressionScript.new()
	var missions := {
		"red_wastes_decoy": {"id": "red_wastes_decoy", "chapter_id": "red_wastes", "order": 2, "type": "seal", "prerequisites": ["other_mission"]},
		"red_wastes_gate": {"id": "red_wastes_gate", "chapter_id": "red_wastes", "order": 2, "type": "seal", "prerequisites": ["red_wastes_survival", "red_wastes_side"]},
		"red_wastes_survival": {"id": "red_wastes_survival", "chapter_id": "red_wastes", "order": 1, "type": "survival", "prerequisites": []},
		"red_wastes_seal": {"id": "red_wastes_seal", "chapter_id": "red_wastes", "order": 3, "type": "seal", "prerequisites": ["red_wastes_survival"]},
	}
	var chapters := {
		"red_wastes": {"id": "red_wastes", "order": 1, "first_mission_id": "red_wastes_survival"},
	}
	var campaign := {
		"completed_missions": {},
		"unlocked_missions": ["red_wastes_survival"],
		"chapter_marks": {"red_wastes": 0},
		"selected_mission_id": "red_wastes_survival",
	}

	runner.assert_eq(system.get_mission_state("red_wastes_survival", campaign, missions, chapters), "available", "first mission should be available")
	runner.assert_eq(system.get_mission_state("red_wastes_seal", campaign, missions, chapters), "locked", "second mission should be locked")

	var locked_before: Dictionary = campaign.duplicate(true)
	var locked_result: Dictionary = system.apply_victory(campaign, "red_wastes_seal", 1, missions, chapters)
	runner.assert_eq(locked_result.get("error", ""), "mission_locked", "locked mission victory should report an error")
	runner.assert_eq(locked_result["campaign"], locked_before, "locked mission victory should leave campaign untouched")
	runner.assert_true(locked_result["newly_unlocked"].is_empty(), "locked mission victory should not unlock another mission")

	var first: Dictionary = system.apply_victory(campaign, "red_wastes_survival", 0, missions, chapters)
	runner.assert_true(first["first_completion"], "first clear should be marked once")
	runner.assert_true(first["newly_unlocked"].has("red_wastes_seal"), "normal clear should unlock the next node")
	runner.assert_true(not first["newly_unlocked"].has("red_wastes_decoy"), "normal clear should ignore adjacent missions without a matching prerequisite")
	runner.assert_true(not first["newly_unlocked"].has("red_wastes_gate"), "normal clear should not unlock a node with unfinished prerequisites")
	runner.assert_eq(first["campaign"]["completed_missions"]["red_wastes_survival"], 0, "victory should store the completed mark")
	runner.assert_true(not first["mark_unlocked"], "normal clear should not unlock a chapter mark")
	var over_mark: Dictionary = system.apply_victory(campaign, "red_wastes_survival", 99, missions, chapters)
	runner.assert_eq(over_mark["campaign"]["completed_missions"]["red_wastes_survival"], 0, "victory should clamp completion to the unlocked chapter mark")

	var joined_campaign: Dictionary = campaign.duplicate(true)
	joined_campaign["completed_missions"]["red_wastes_side"] = 0
	var joined_result: Dictionary = system.apply_victory(joined_campaign, "red_wastes_survival", 0, missions, chapters)
	runner.assert_true(joined_result["newly_unlocked"].has("red_wastes_gate"), "node should unlock after every prerequisite is complete")
	runner.assert_true(not joined_result["newly_unlocked"].has("red_wastes_seal"), "only the nearest eligible node should unlock")

	var repeat: Dictionary = system.apply_victory(first["campaign"], "red_wastes_survival", 0, missions, chapters)
	runner.assert_true(not repeat["first_completion"], "repeat clear should not repeat first rewards")
	runner.assert_true(repeat["newly_unlocked"].is_empty(), "repeat clear should not duplicate unlocks")
	runner.assert_true(not repeat["mark_unlocked"], "repeat clear should not duplicate mark unlocks")

	var mastered_campaign: Dictionary = first["campaign"].duplicate(true)
	mastered_campaign["chapter_marks"]["red_wastes"] = 1
	runner.assert_eq(system.get_mission_state("red_wastes_survival", mastered_campaign, missions, chapters), "completed", "lower mark clear should be completed")
	mastered_campaign["completed_missions"]["red_wastes_survival"] = 1
	runner.assert_eq(system.get_mission_state("red_wastes_survival", mastered_campaign, missions, chapters), "mastered", "matching mark clear should be mastered")
	var missing_chapter_missions := {
		"orphan_mission": {"id": "orphan_mission", "chapter_id": "missing_chapter", "order": 1, "type": "survival"},
	}
	runner.assert_eq(system.get_mission_state("orphan_mission", {"unlocked_missions": ["orphan_mission"]}, missing_chapter_missions, {}), "locked", "mission with missing chapter should be locked")

	var boss_missions := {
		"red_wastes_boss": {"id": "red_wastes_boss", "chapter_id": "red_wastes", "order": 1, "type": "boss"},
		"bamboo_ruins_survival": {"id": "bamboo_ruins_survival", "chapter_id": "bamboo_ruins", "order": 1, "type": "survival"},
	}
	var boss_chapters := {
		"red_wastes": {"id": "red_wastes", "order": 1, "first_mission_id": "red_wastes_boss"},
		"bamboo_ruins": {"id": "bamboo_ruins", "order": 2, "first_mission_id": "bamboo_ruins_survival"},
	}
	var boss_campaign := {
		"completed_missions": {},
		"unlocked_missions": ["red_wastes_boss"],
		"chapter_marks": {"red_wastes": 0, "bamboo_ruins": 0},
	}
	var boss_result: Dictionary = system.apply_victory(boss_campaign, "red_wastes_boss", 2, boss_missions, boss_chapters)
	runner.assert_true(boss_result["newly_unlocked"].has("bamboo_ruins_survival"), "boss clear should unlock the next chapter first mission")
	runner.assert_eq(boss_result["campaign"]["completed_missions"]["red_wastes_boss"], 0, "boss clear should not record a locked difficulty mark")
	runner.assert_eq(boss_result["campaign"]["chapter_marks"]["red_wastes"], 1, "boss clear should raise the completed chapter mark")
	runner.assert_true(boss_result["mark_unlocked"], "boss clear should report a newly unlocked mark")

	var before_unknown: Dictionary = boss_campaign.duplicate(true)
	var unknown_result: Dictionary = system.apply_victory(boss_campaign, "missing", 1, boss_missions, boss_chapters)
	runner.assert_eq(unknown_result.get("error", ""), "unknown_mission", "unknown mission should report an error")
	runner.assert_eq(unknown_result["campaign"], before_unknown, "unknown mission should leave campaign untouched")
