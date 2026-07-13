extends RefCounted

func get_mission_state(mission_id: String, campaign: Dictionary, missions: Dictionary, chapters: Dictionary) -> String:
	if not missions.has(mission_id):
		return "locked"
	if not Array(campaign.get("unlocked_missions", [])).has(mission_id):
		return "locked"

	var completed_missions: Dictionary = campaign.get("completed_missions", {})
	if not completed_missions.has(mission_id):
		return "available"

	var mission: Dictionary = missions[mission_id]
	var chapter_id := String(mission.get("chapter_id", ""))
	var chapter_marks: Dictionary = campaign.get("chapter_marks", {})
	var current_chapter_mark := int(chapter_marks.get(chapter_id, 0))
	if int(completed_missions[mission_id]) >= current_chapter_mark:
		return "mastered"
	return "completed"

func apply_victory(campaign: Dictionary, mission_id: String, difficulty_mark: int, missions: Dictionary, chapters: Dictionary) -> Dictionary:
	var result := {
		"campaign": campaign.duplicate(true),
		"first_completion": false,
		"newly_unlocked": [],
		"mark_unlocked": false,
	}
	if not missions.has(mission_id):
		result["error"] = "unknown_mission"
		return result

	var updated_campaign: Dictionary = result["campaign"]
	var completed_missions: Dictionary = updated_campaign.get("completed_missions", {})
	var mark := maxi(0, difficulty_mark)
	if not completed_missions.has(mission_id):
		result["first_completion"] = true
		completed_missions[mission_id] = mark
	else:
		var previous_mark := int(completed_missions[mission_id])
		completed_missions[mission_id] = maxi(previous_mark, mark)
	updated_campaign["completed_missions"] = completed_missions

	var unlocked_missions: Array = Array(updated_campaign.get("unlocked_missions", [])).duplicate()
	var mission: Dictionary = missions[mission_id]
	var next_mission_id := _find_next_mission_id(mission, missions, chapters)
	if next_mission_id != "" and not unlocked_missions.has(next_mission_id):
		unlocked_missions.append(next_mission_id)
		result["newly_unlocked"].append(next_mission_id)
	updated_campaign["unlocked_missions"] = unlocked_missions

	if String(mission.get("type", "")) == "boss":
		var chapter_id := String(mission.get("chapter_id", ""))
		var chapter_marks: Dictionary = updated_campaign.get("chapter_marks", {})
		var previous_chapter_mark := int(chapter_marks.get(chapter_id, 0))
		chapter_marks[chapter_id] = maxi(previous_chapter_mark, 1)
		updated_campaign["chapter_marks"] = chapter_marks
		result["mark_unlocked"] = result["mark_unlocked"] or previous_chapter_mark < 1

	result["campaign"] = updated_campaign
	return result

func _find_next_mission_id(mission: Dictionary, missions: Dictionary, chapters: Dictionary) -> String:
	var chapter_id := String(mission.get("chapter_id", ""))
	var mission_order := int(mission.get("order", 0))
	if String(mission.get("type", "")) != "boss":
		for candidate in missions.values():
			if String(candidate.get("chapter_id", "")) == chapter_id and int(candidate.get("order", 0)) == mission_order + 1:
				return String(candidate.get("id", ""))
		return ""

	var chapter: Dictionary = chapters.get(chapter_id, {})
	var completed_chapter_order := int(chapter.get("order", 0))
	var next_chapter_order := completed_chapter_order + 1
	for candidate_chapter in chapters.values():
		if int(candidate_chapter.get("order", 0)) == next_chapter_order:
			return String(candidate_chapter.get("first_mission_id", ""))
	return ""
