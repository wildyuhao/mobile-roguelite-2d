extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/data/game_database.gd"):
		runner.assert_true(false, "database loader script should exist")
		return

	var game_database_script = load("res://scripts/data/game_database.gd")
	var db = game_database_script.new()
	var result = db.load_all()

	runner.assert_true(result, "database load_all should return true")
	runner.assert_true(db.has_weapon("flying_sword"), "database should include flying_sword")
	var expected_weapon_names := {
		"flying_sword": "飞剑",
		"talisman_fire": "符火",
		"mechanism_crossbow": "机关连弩",
		"demon_sealing_bell": "封魔铃",
		"spirit_needle_array": "灵针阵",
	}
	for weapon_id in expected_weapon_names.keys():
		runner.assert_eq(
			db.get_weapon(weapon_id).get("display_name", ""),
			expected_weapon_names[weapon_id],
			"%s should use its Chinese display name" % weapon_id
		)
		runner.assert_true(
			_has_cjk(String(db.get_weapon(weapon_id).get("description", ""))),
			"%s description should contain Chinese text" % weapon_id
		)
	for upgrade in db.get_upgrades():
		runner.assert_true(
			_has_cjk(String(upgrade.get("display_name", ""))),
			"%s should use a Chinese display name" % upgrade.get("id", "")
		)
	runner.assert_true(db.has_enemy("basic_demon"), "database should include basic_demon")
	runner.assert_true(db.get_upgrades().size() >= 20, "combat density foundation should include at least twenty upgrades")
	runner.assert_true(db.get_wave_events().size() >= 2, "database should include wave events")
	_assert_early_wave_pressure(runner, db.get_wave_events())
	_assert_three_minute_wave_density(runner, db.get_wave_events())
	runner.assert_true(db.has_method("get_weapons"), "database should expose all weapons")
	runner.assert_true(db.has_method("get_enemies"), "database should expose all enemies")
	runner.assert_true(db.has_weapon("spirit_needle_array"), "database should include spirit_needle_array")
	runner.assert_true(db.get_weapons().size() >= 5, "combat density foundation should include five weapons")
	for weapon_id in ["flying_sword", "talisman_fire", "mechanism_crossbow", "spirit_needle_array"]:
		var texture_path := String(db.get_weapon(weapon_id).get("projectile_texture_path", ""))
		runner.assert_true(texture_path != "", "%s should declare a projectile texture" % weapon_id)
		runner.assert_true(ResourceLoader.exists(texture_path), "%s projectile texture should exist" % weapon_id)
	runner.assert_true(db.get_enemies().size() >= 5, "vertical slice should include four enemies and one boss")
	runner.assert_true(db.get_equipment().size() >= 6, "vertical slice should include six equipment items")
	var equipment_names: Dictionary = {}
	for equipment in db.get_equipment():
		equipment_names[equipment.get("id", "")] = equipment.get("display_name", "")
	var expected_equipment_names := {
		"talisman_robe": "符甲法袍",
		"sword_gourd": "剑葫芦",
		"jade_compass": "聚灵盘",
		"bronze_gear_core": "机关核心",
		"cloudstep_boots": "踏云靴",
		"bell_charm": "镇魂珠",
	}
	for equipment_id in expected_equipment_names.keys():
		runner.assert_eq(
			equipment_names.get(equipment_id, ""),
			expected_equipment_names[equipment_id],
			"%s should use its Chinese display name" % equipment_id
		)
	runner.assert_true(db.has_method("get_encounters"), "database should expose encounter cards")
	runner.assert_true(db.has_method("get_formations"), "database should expose formation templates")
	if db.has_method("get_encounters") and db.has_method("get_formations"):
		var encounters: Array[Dictionary] = db.get_encounters()
		var formations: Dictionary = db.get_formations()
		runner.assert_eq(encounters.size(), 7, "first chapter should define seven encounter cards")
		runner.assert_eq(formations.size(), 7, "first chapter should define seven formations")
		for encounter in encounters:
			runner.assert_true(
				formations.has(String(encounter.get("formation_id", ""))),
				"encounter formation should resolve"
			)
			for group in encounter.get("groups", []):
				runner.assert_true(
					db.has_enemy(String(group.get("enemy_id", ""))),
					"encounter enemy should resolve"
				)
	for enemy_id in db.get_enemies().keys():
		var enemy: Dictionary = db.get_enemy(enemy_id)
		runner.assert_true(
			String(enemy.get("role", "")) != "",
			"%s should declare a role" % enemy_id
		)
		runner.assert_true(
			int(enemy.get("pressure_cost", 0)) > 0,
			"%s should declare pressure cost" % enemy_id
		)

func _assert_early_wave_pressure(runner, wave_events: Array[Dictionary]) -> void:
	var first_minute_times: Array[float] = []
	for event in wave_events:
		var event_time := float(event.get("time", 9999.0))
		if event_time <= 60.0:
			first_minute_times.append(event_time)
	first_minute_times.sort()

	runner.assert_true(first_minute_times.size() >= 6, "first minute should include enough enemy waves to keep combat active")
	if first_minute_times.size() < 2:
		return
	for index in range(1, first_minute_times.size()):
		var gap := first_minute_times[index] - first_minute_times[index - 1]
		runner.assert_true(gap <= 12.0, "first-minute enemy wave gap should not exceed 12 seconds")

func _assert_three_minute_wave_density(runner, wave_events: Array[Dictionary]) -> void:
	var event_times: Array[float] = []
	var enemy_ids: Dictionary = {}
	var total_spawn_count := 0
	for event in wave_events:
		var event_time := float(event.get("time", 9999.0))
		if event_time > 180.0:
			continue
		event_times.append(event_time)
		enemy_ids[String(event.get("enemy_id", ""))] = true
		total_spawn_count += int(event.get("spawn_count", 0))
	event_times.sort()

	runner.assert_true(event_times.size() >= 17, "first three minutes should include at least seventeen wave events")
	runner.assert_true(total_spawn_count >= 145, "first three minutes should request at least 145 enemies")
	runner.assert_true(enemy_ids.has("basic_demon"), "first three minutes should include basic demons")
	runner.assert_true(enemy_ids.has("charging_demon"), "first three minutes should include charging demons")
	runner.assert_true(enemy_ids.has("ranged_demon"), "first three minutes should include ranged demons")
	runner.assert_true(enemy_ids.has("elite_guardian"), "first three minutes should introduce an elite")
	for index in range(1, event_times.size()):
		var gap := event_times[index] - event_times[index - 1]
		runner.assert_true(gap <= 12.0, "three-minute wave gap should not exceed 12 seconds")

func _has_cjk(text: String) -> bool:
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if codepoint >= 0x4E00 and codepoint <= 0x9FFF:
			return true
	return false
