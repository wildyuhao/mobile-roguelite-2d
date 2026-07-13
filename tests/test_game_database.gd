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
		"sword_gourd_blades": "剑葫芦",
		"frost_talisman": "寒霜符",
		"soul_lantern": "引魂灯",
	}
	runner.assert_eq(db.get_weapons().size(), 8, "production catalog should contain exactly eight weapons")
	var school_counts := {
		"sword": 0,
		"talisman": 0,
		"mechanism": 0,
		"soul": 0,
	}
	for weapon_id in expected_weapon_names.keys():
		var definition: Dictionary = db.get_weapon(weapon_id)
		runner.assert_eq(
			definition.get("display_name", ""),
			expected_weapon_names[weapon_id],
			"%s should use its Chinese display name" % weapon_id
		)
		runner.assert_true(
			_has_cjk(String(definition.get("description", ""))),
			"%s description should contain Chinese text" % weapon_id
		)
		runner.assert_eq(definition.get("version", 0), 1, "%s should use modular schema version one" % weapon_id)
		runner.assert_true(not Array(definition.get("effects", [])).is_empty(), "%s should define modular effects" % weapon_id)
		var school := String(definition.get("school", ""))
		if school_counts.has(school):
			school_counts[school] = int(school_counts[school]) + 1
		for visual_path in _collect_visual_paths(definition):
			runner.assert_true(
				ResourceLoader.exists(visual_path),
				"%s visual should exist: %s" % [weapon_id, visual_path]
			)
		for legacy_key in ["type", "base_damage", "cooldown", "projectile_speed"]:
			runner.assert_true(not definition.has(legacy_key), "%s should not keep legacy field %s" % [weapon_id, legacy_key])
	for school in school_counts.keys():
		runner.assert_eq(
			school_counts[school],
			2,
			"%s school should contain exactly two weapons" % school
		)
	runner.assert_true(not db.has_weapon("sword_gourd"), "equipment id sword_gourd must not collide with a weapon id")
	_assert_new_weapon_signatures(runner, db)
	for upgrade in db.get_upgrades():
		var upgrade_id := String(upgrade.get("id", ""))
		runner.assert_true(
			_has_cjk(String(upgrade.get("display_name", ""))),
			"%s should use a Chinese display name" % upgrade_id
		)
		var icon_path := String(upgrade.get("icon_path", ""))
		runner.assert_true(icon_path != "", "%s should define an upgrade icon" % upgrade_id)
		runner.assert_true(ResourceLoader.exists(icon_path), "%s icon should exist" % upgrade_id)
		if ResourceLoader.exists(icon_path):
			runner.assert_true(
				load(icon_path) is Texture2D,
				"%s icon should load as a texture" % upgrade_id
			)
	runner.assert_true(db.has_enemy("basic_demon"), "database should include basic_demon")
	var charging_demon: Dictionary = db.get_enemy("charging_demon")
	runner.assert_eq(charging_demon.get("display_name", ""), "角冲妖", "charger should use its Chinese name")
	runner.assert_eq(int(charging_demon.get("charge_trigger_range", 0)), 300, "charger trigger range")
	runner.assert_eq(int(charging_demon.get("charge_speed", 0)), 420, "charger speed")
	runner.assert_near(
		float(charging_demon.get("charge_speed", 0.0)) * float(charging_demon.get("attack_active", 0.0)),
		294.0,
		0.01,
		"charger warning distance should match its active travel"
	)
	runner.assert_true(db.get_upgrades().size() >= 20, "combat density foundation should include at least twenty upgrades")
	runner.assert_true(db.get_wave_events().size() >= 2, "database should include wave events")
	_assert_early_wave_pressure(runner, db.get_wave_events())
	_assert_three_minute_wave_density(runner, db.get_wave_events())
	runner.assert_true(db.has_method("get_weapons"), "database should expose all weapons")
	runner.assert_true(db.has_method("get_enemies"), "database should expose all enemies")
	runner.assert_true(db.has_weapon("spirit_needle_array"), "database should include spirit_needle_array")
	runner.assert_eq(db.get_weapons().size(), 8, "modular catalog should include eight weapons")
	var validator = load("res://scripts/weapons/weapon_definition_validator.gd").new()
	runner.assert_true(validator.validate_catalog(db.get_weapons()).is_empty(), "loaded weapon catalog should pass modular validation")
	for weapon_id in ["flying_sword", "talisman_fire", "mechanism_crossbow", "spirit_needle_array"]:
		var texture_path := String(Dictionary(db.get_weapon(weapon_id).get("visual", {})).get("carrier", ""))
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

func _collect_visual_paths(definition: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	for path_value in Dictionary(definition.get("visual", {})).values():
		paths.append(String(path_value))
	for effect_value in definition.get("effects", []):
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		for path_value in Dictionary(effect_value.get("visual", {})).values():
			paths.append(String(path_value))
	return paths

func _assert_new_weapon_signatures(runner, db) -> void:
	var sword: Dictionary = db.get_weapon("sword_gourd_blades")
	if not sword.is_empty():
		runner.assert_true(
			_has_effect_signature(sword, "persistent", "", "orbit", ""),
			"sword gourd should include persistent orbit blades"
		)
		runner.assert_true(
			_has_effect_signature(sword, "on_player_hit", "", "projectile", ""),
			"sword gourd should unlock retaliating projectiles"
		)
	var frost: Dictionary = db.get_weapon("frost_talisman")
	if not frost.is_empty():
		runner.assert_true(
			_has_effect_signature(frost, "periodic", "sector", "projectile", "freeze"),
			"frost talisman should fire freezing sector projectiles"
		)
	var lantern: Dictionary = db.get_weapon("soul_lantern")
	if not lantern.is_empty():
		runner.assert_true(
			_has_effect_signature(lantern, "periodic", "", "summon", ""),
			"soul lantern should periodically summon soul flames"
		)

func _has_effect_signature(
	definition: Dictionary,
	trigger_id: String,
	target_id: String,
	carrier_id: String,
	status_id: String
) -> bool:
	for effect_value in definition.get("effects", []):
		var effect: Dictionary = effect_value
		if String(Dictionary(effect.get("trigger", {})).get("id", "")) != trigger_id:
			continue
		if target_id != "" and String(Dictionary(effect.get("target", {})).get("id", "")) != target_id:
			continue
		if String(Dictionary(effect.get("carrier", {})).get("id", "")) != carrier_id:
			continue
		if status_id == "":
			return true
		for status_value in Dictionary(effect.get("hit", {})).get("statuses", []):
			if String(Dictionary(status_value).get("id", "")) == status_id:
				return true
	return false
