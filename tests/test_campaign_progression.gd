extends RefCounted

const CampaignProgressionScript = preload("res://scripts/systems/campaign_progression.gd")

func run(runner) -> void:
	var system = CampaignProgressionScript.new()
	var missions := {
		"red_wastes_survival": {"id": "red_wastes_survival", "chapter_id": "red_wastes", "order": 1, "type": "survival"},
		"red_wastes_seal": {"id": "red_wastes_seal", "chapter_id": "red_wastes", "order": 2, "type": "seal"},
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

	var first: Dictionary = system.apply_victory(campaign, "red_wastes_survival", 0, missions, chapters)
	runner.assert_true(first["first_completion"], "first clear should be marked once")
	runner.assert_true(first["newly_unlocked"].has("red_wastes_seal"), "normal clear should unlock the next node")
	runner.assert_eq(first["campaign"]["completed_missions"]["red_wastes_survival"], 0, "victory should store the completed mark")
	runner.assert_true(not first["mark_unlocked"], "normal clear should not unlock a chapter mark")

	var repeat: Dictionary = system.apply_victory(first["campaign"], "red_wastes_survival", 0, missions, chapters)
	runner.assert_true(not repeat["first_completion"], "repeat clear should not repeat first rewards")
	runner.assert_true(repeat["newly_unlocked"].is_empty(), "repeat clear should not duplicate unlocks")
	runner.assert_true(not repeat["mark_unlocked"], "repeat clear should not duplicate mark unlocks")

	var mastered_campaign: Dictionary = first["campaign"].duplicate(true)
	mastered_campaign["chapter_marks"]["red_wastes"] = 1
	runner.assert_eq(system.get_mission_state("red_wastes_survival", mastered_campaign, missions, chapters), "completed", "lower mark clear should be completed")
	mastered_campaign["completed_missions"]["red_wastes_survival"] = 1
	runner.assert_eq(system.get_mission_state("red_wastes_survival", mastered_campaign, missions, chapters), "mastered", "matching mark clear should be mastered")

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
	runner.assert_eq(boss_result["campaign"]["chapter_marks"]["red_wastes"], 1, "boss clear should raise the completed chapter mark")
	runner.assert_true(boss_result["mark_unlocked"], "boss clear should report a newly unlocked mark")

	var before_unknown: Dictionary = boss_campaign.duplicate(true)
	var unknown_result: Dictionary = system.apply_victory(boss_campaign, "missing", 1, boss_missions, boss_chapters)
	runner.assert_eq(unknown_result.get("error", ""), "unknown_mission", "unknown mission should report an error")
	runner.assert_eq(unknown_result["campaign"], before_unknown, "unknown mission should leave campaign untouched")
