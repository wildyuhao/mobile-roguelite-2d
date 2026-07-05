extends RefCounted
class_name UpgradeSystem

var upgrades: Array[Dictionary] = []

func configure(new_upgrades: Array[Dictionary]) -> void:
	upgrades = new_upgrades.duplicate(true)

func get_choices(runtime_state: Dictionary, count: int = 3, seed_value: int = 0) -> Array[Dictionary]:
	var available := _get_available_upgrades(runtime_state)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()

	var choices: Array[Dictionary] = []
	while not available.is_empty() and choices.size() < count:
		var index := rng.randi_range(0, available.size() - 1)
		choices.append(available[index])
		available.remove_at(index)
	return choices

func apply_upgrade(runtime_state: Dictionary, upgrade: Dictionary) -> void:
	if not runtime_state.has("upgrade_stacks"):
		runtime_state["upgrade_stacks"] = {}

	var id: String = upgrade["id"]
	var stacks: Dictionary = runtime_state["upgrade_stacks"]
	stacks[id] = int(stacks.get(id, 0)) + 1

	if upgrade.get("kind", "") == "weapon_level":
		var weapon_id: String = upgrade.get("weapon_id", "")
		var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
		owned_weapons[weapon_id] = int(owned_weapons.get(weapon_id, 1)) + 1
		runtime_state["owned_weapons"] = owned_weapons
	elif upgrade.get("kind", "") == "weapon_unlock":
		var weapon_id: String = upgrade.get("weapon_id", "")
		var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
		if weapon_id != "" and not owned_weapons.has(weapon_id):
			owned_weapons[weapon_id] = 1
		runtime_state["owned_weapons"] = owned_weapons

func _get_available_upgrades(runtime_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})
	var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})

	for upgrade in upgrades:
		var id: String = upgrade["id"]
		var current_stacks := int(stacks.get(id, 0))
		var max_stacks := int(upgrade.get("max_stacks", 1))
		if current_stacks >= max_stacks:
			continue

		if upgrade.get("kind", "") == "weapon_level":
			var weapon_id: String = upgrade.get("weapon_id", "")
			if not owned_weapons.has(weapon_id):
				continue
		elif upgrade.get("kind", "") == "weapon_unlock":
			var weapon_id: String = upgrade.get("weapon_id", "")
			if owned_weapons.has(weapon_id):
				continue

		result.append(upgrade)

	return result
