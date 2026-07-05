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
