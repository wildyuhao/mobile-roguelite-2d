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

	var runtime_state := {
		"owned_weapons": { "flying_sword": 1 },
		"upgrade_stacks": {}
	}

	var choices = system.get_choices(runtime_state, 3, 12345)
	runner.assert_eq(choices.size(), 3, "upgrade system should return three choices")
	runner.assert_true(_all_unique(choices), "choices should be unique")

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
