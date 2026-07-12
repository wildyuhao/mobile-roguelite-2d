extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/data/game_database.gd"):
		runner.assert_true(false, "database script should exist")
		return
	if not ResourceLoader.exists("res://scripts/systems/upgrade_system.gd"):
		runner.assert_true(false, "upgrade system script should exist")
		return

	var game_database_script = load("res://scripts/data/game_database.gd")
	var upgrade_system_script = load("res://scripts/systems/upgrade_system.gd")

	var db = game_database_script.new()
	runner.assert_true(db.load_all(), "database should load before upgrade tests")

	var system = upgrade_system_script.new()
	system.configure(db.get_upgrades())
	_assert_new_weapon_upgrades(runner, db.get_upgrades())

	var runtime_state := {
		"owned_weapons": { "flying_sword": 1 },
		"upgrade_stacks": {}
	}

	var choices = system.get_choices(runtime_state, 3, 12345)
	runner.assert_eq(choices.size(), 3, "upgrade system should return three choices")
	runner.assert_true(_all_unique(choices), "choices should be unique")
	for seed_value in range(1, 65):
		var opening_choices = system.get_choices(runtime_state, 3, seed_value)
		runner.assert_true(
			_has_kind(opening_choices, "weapon_unlock"),
			"opening choices should always offer a second weapon for seed %d" % seed_value
		)

	var summary_system = upgrade_system_script.new()
	var summary_upgrades: Array[Dictionary] = [
		{
			"id": "weapon_damage_1",
			"display_name": "锋刃淬炼",
			"kind": "stat",
			"stat": "weapon_damage_multiplier",
			"value": 0.15,
			"max_stacks": 1,
		},
		{
			"id": "flying_sword_level",
			"display_name": "飞剑精通",
			"kind": "weapon_level",
			"weapon_id": "flying_sword",
			"max_stacks": 1,
		},
		{
			"id": "unlock_talisman_fire",
			"display_name": "习得符火",
			"kind": "weapon_unlock",
			"weapon_id": "talisman_fire",
			"max_stacks": 1,
		},
		{
			"id": "unlock_frost_talisman",
			"display_name": "习得寒霜符",
			"kind": "weapon_unlock",
			"weapon_id": "frost_talisman",
			"max_stacks": 1,
			"effect_summary": "向前方扇区齐射三道寒符",
		},
	]
	summary_system.configure(summary_upgrades)
	var summary_choices = summary_system.get_choices(runtime_state, 4, 99)
	runner.assert_eq(_find_choice(summary_choices, "weapon_damage_1").get("effect_summary", ""), "伤害 +15%", "stat upgrade choices should use Chinese effect text")
	runner.assert_eq(_find_choice(summary_choices, "flying_sword_level").get("effect_summary", ""), "武器等级 +1", "weapon level choices should use Chinese effect text")
	runner.assert_eq(_find_choice(summary_choices, "unlock_talisman_fire").get("effect_summary", ""), "解锁武器", "weapon unlock choices should use Chinese effect text")
	runner.assert_eq(
		_find_choice(summary_choices, "unlock_frost_talisman").get("effect_summary", ""),
		"向前方扇区齐射三道寒符",
		"authored weapon summaries should override generic text"
	)

	var damage_upgrade := _find_choice(choices, "weapon_damage_1")
	if damage_upgrade.is_empty():
		damage_upgrade = db.get_upgrades()[0]

	system.apply_upgrade(runtime_state, damage_upgrade)
	runner.assert_eq(runtime_state["upgrade_stacks"][damage_upgrade["id"]], 1, "selected upgrade stack increments")

	var unlock_upgrade := {
		"id": "unlock_talisman_fire",
		"kind": "weapon_unlock",
		"weapon_id": "talisman_fire"
	}
	system.apply_upgrade(runtime_state, unlock_upgrade)
	runner.assert_true(runtime_state["owned_weapons"].has("talisman_fire"), "weapon unlock should add weapon id")
	if runtime_state["owned_weapons"].has("talisman_fire"):
		runner.assert_eq(runtime_state["owned_weapons"]["talisman_fire"], 1, "weapon unlock should add weapon at level 1")

	var pickup_upgrade := _find_upgrade(db.get_upgrades(), "pickup_radius_1")
	system.apply_upgrade(runtime_state, pickup_upgrade)
	system.apply_upgrade(runtime_state, pickup_upgrade)
	if system.has_method("get_stat_modifiers"):
		var modifiers: Dictionary = system.get_stat_modifiers(runtime_state)
		runner.assert_eq(modifiers["pickup_radius"], 48, "stacked stat upgrades should produce pickup radius modifiers")
	else:
		runner.assert_true(false, "upgrade system should expose stat modifiers from selected upgrades")

	var bundle_system = upgrade_system_script.new()
	var bundle_upgrades: Array[Dictionary] = [
		{
			"id": "heavy_seal",
			"display_name": "重山封印",
			"kind": "stat_bundle",
			"stat_modifiers": {
				"weapon_damage_multiplier": 0.25,
				"move_speed": -10,
			},
			"max_stacks": 2,
		},
	]
	bundle_system.configure(bundle_upgrades)
	var bundle_choices = bundle_system.get_choices(runtime_state, 1, 77)
	runner.assert_eq(bundle_choices.size(), 1, "stat bundle should be a valid upgrade choice")
	runner.assert_eq(bundle_choices[0].get("effect_summary", ""), "伤害 +25%，移速 -10", "stat bundle should summarize every modifier in Chinese")
	var bundle_state := { "owned_weapons": {}, "upgrade_stacks": {} }
	bundle_system.apply_upgrade(bundle_state, bundle_choices[0])
	var bundle_modifiers = bundle_system.get_stat_modifiers(bundle_state)
	runner.assert_near(float(bundle_modifiers.get("weapon_damage_multiplier", 0.0)), 0.25, 0.001, "bundle damage modifier should apply")
	runner.assert_eq(bundle_modifiers.get("move_speed", 0), -10, "bundle speed tradeoff should apply")

	var full_weapon_state := {
		"owned_weapons": {
			"flying_sword": 1,
			"talisman_fire": 1,
			"mechanism_crossbow": 1,
			"demon_sealing_bell": 1,
		},
		"upgrade_stacks": {},
		"max_weapon_slots": 99,
	}
	var full_choices = system.get_choices(full_weapon_state, 20, 2026)
	runner.assert_true(
		not _has_kind(full_choices, "weapon_unlock"),
		"the four-slot cap should not be raised by runtime state"
	)
	var rejected_unlock := _find_upgrade(db.get_upgrades(), "unlock_spirit_needle_array")
	var applied = system.apply_upgrade(full_weapon_state, rejected_unlock)
	runner.assert_true(applied != true, "full weapon slots should reject direct unlock application")
	runner.assert_eq(full_weapon_state["owned_weapons"].size(), 4, "rejected unlock should preserve four owned weapons")
	runner.assert_true(not full_weapon_state["owned_weapons"].has("spirit_needle_array"), "rejected unlock should not add a fifth weapon")
	runner.assert_true(not full_weapon_state["upgrade_stacks"].has("unlock_spirit_needle_array"), "rejected unlock should not consume its stack")

	var duplicate_system = upgrade_system_script.new()
	var duplicate_unlock := rejected_unlock.duplicate(true)
	var duplicate_upgrades: Array[Dictionary] = [
		rejected_unlock,
		duplicate_unlock,
		_find_upgrade(db.get_upgrades(), "weapon_damage_1"),
	]
	duplicate_system.configure(duplicate_upgrades)
	var duplicate_choices = duplicate_system.get_choices({
		"owned_weapons": { "flying_sword": 1 },
		"upgrade_stacks": {},
	}, 3, 9)
	runner.assert_true(
		_all_unique(duplicate_choices),
		"duplicate upgrade definitions should appear at most once per draw"
	)

func _all_unique(choices: Array) -> bool:
	var seen := {}
	for choice in choices:
		if seen.has(choice["id"]):
			return false
		seen[choice["id"]] = true
	return true

func _find_choice(choices: Array, id: String) -> Dictionary:
	for choice in choices:
		if choice["id"] == id:
			return choice
	return {}

func _find_upgrade(upgrades: Array, id: String) -> Dictionary:
	for upgrade in upgrades:
		if upgrade["id"] == id:
			return upgrade
	return {}

func _has_kind(choices: Array, kind: String) -> bool:
	for choice in choices:
		if String(choice.get("kind", "")) == kind:
			return true
	return false

func _assert_new_weapon_upgrades(runner, upgrades: Array[Dictionary]) -> void:
	var expected := {
		"unlock_sword_gourd_blades": ["weapon_unlock", "sword_gourd_blades", 1],
		"sword_gourd_blades_level": ["weapon_level", "sword_gourd_blades", 4],
		"unlock_frost_talisman": ["weapon_unlock", "frost_talisman", 1],
		"frost_talisman_level": ["weapon_level", "frost_talisman", 4],
		"unlock_soul_lantern": ["weapon_unlock", "soul_lantern", 1],
		"soul_lantern_level": ["weapon_level", "soul_lantern", 4],
	}
	for upgrade_id in expected.keys():
		var upgrade := _find_upgrade(upgrades, upgrade_id)
		runner.assert_true(not upgrade.is_empty(), "%s should exist" % upgrade_id)
		if upgrade.is_empty():
			continue
		var signature: Array = expected[upgrade_id]
		runner.assert_eq(upgrade.get("kind", ""), signature[0], "%s kind" % upgrade_id)
		runner.assert_eq(upgrade.get("weapon_id", ""), signature[1], "%s weapon id" % upgrade_id)
		runner.assert_eq(upgrade.get("max_stacks", 0), signature[2], "%s stack count" % upgrade_id)
		runner.assert_true(_has_cjk(String(upgrade.get("display_name", ""))), "%s should have a Chinese name" % upgrade_id)
		var summary := String(upgrade.get("effect_summary", ""))
		runner.assert_true(_has_cjk(summary), "%s should have an authored Chinese behavior summary" % upgrade_id)
		runner.assert_true(summary not in ["解锁武器", "武器等级 +1"], "%s summary should describe behavior" % upgrade_id)

func _has_cjk(text: String) -> bool:
	for index in range(text.length()):
		var codepoint := text.unicode_at(index)
		if codepoint >= 0x4E00 and codepoint <= 0x9FFF:
			return true
	return false
