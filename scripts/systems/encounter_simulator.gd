extends RefCounted
class_name EncounterSimulator

const EncounterBagScript = preload("res://scripts/systems/encounter_bag.gd")
const PressureBudgetScript = preload("res://scripts/systems/pressure_budget.gd")

func simulate(
	cards: Array[Dictionary],
	duration: float,
	seed: int
) -> Dictionary:
	var bag = EncounterBagScript.new()
	var budget = PressureBudgetScript.new()
	bag.configure(cards, seed)
	var elapsed := 45.0
	var sequence: Array[String] = []
	var unique: Dictionary = {}
	var triple_repeats := 0
	var ranged_units := 0
	var total_units := 0
	var max_budget := 0

	while elapsed <= duration:
		var available := budget.get_budget(elapsed)
		max_budget = maxi(max_budget, available)
		var card: Dictionary = bag.draw(elapsed, available)
		if not card.is_empty():
			var id := String(card.get("id", ""))
			sequence.append(id)
			unique[id] = true
			if (
				sequence.size() >= 3
				and sequence[-1] == sequence[-2]
				and sequence[-2] == sequence[-3]
			):
				triple_repeats += 1
			for group in card.get("groups", []):
				var count := int(group.get("count", 0))
				total_units += count
				if String(group.get("enemy_id", "")) == "ranged_demon":
					ranged_units += count
		elapsed += 52.0

	return {
		"draw_count": sequence.size(),
		"unique_count": unique.size(),
		"triple_repeats": triple_repeats,
		"ranged_share": float(ranged_units) / float(maxi(1, total_units)),
		"max_budget": max_budget,
		"sequence": sequence,
	}
