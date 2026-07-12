extends RefCounted
class_name EncounterBag

var cards: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var draw_index: int = 0
var last_draw_by_id: Dictionary = {}
var recent_ids: Array[String] = []
var recent_signatures: Array[String] = []

func configure(new_cards: Array[Dictionary], seed: int) -> void:
	cards = new_cards.duplicate(true)
	rng.seed = seed
	draw_index = 0
	last_draw_by_id.clear()
	recent_ids.clear()
	recent_signatures.clear()

func draw(elapsed: float, budget: int) -> Dictionary:
	var eligible: Array[Dictionary] = []
	var total_weight := 0
	for card in cards:
		if (
			elapsed < float(card.get("min_time", 0.0))
			or elapsed > float(card.get("max_time", INF))
		):
			continue
		if int(card.get("pressure_cost", 0)) > budget:
			continue
		var id := String(card.get("id", ""))
		var cooldown := int(card.get("cooldown_draws", 0))
		if (
			last_draw_by_id.has(id)
			and draw_index - int(last_draw_by_id[id]) <= cooldown
		):
			continue
		var signature := enemy_signature(card)
		if (
			_would_repeat_three(recent_ids, id)
			or _would_repeat_three(recent_signatures, signature)
		):
			continue
		eligible.append(card)
		total_weight += maxi(1, int(card.get("weight", 1)))

	if eligible.is_empty() or total_weight <= 0:
		return {}

	var ticket := rng.randi_range(1, total_weight)
	var selected: Dictionary = eligible[0]
	for card in eligible:
		ticket -= maxi(1, int(card.get("weight", 1)))
		if ticket <= 0:
			selected = card
			break

	var selected_id := String(selected.get("id", ""))
	var signature := enemy_signature(selected)
	draw_index += 1
	last_draw_by_id[selected_id] = draw_index
	_push_recent(recent_ids, selected_id)
	_push_recent(recent_signatures, signature)
	return selected.duplicate(true)

func enemy_signature(card: Dictionary) -> String:
	var ids: Array[String] = []
	for group in card.get("groups", []):
		ids.append(String(group.get("enemy_id", "")))
	ids.sort()
	return "+".join(PackedStringArray(ids))

func _would_repeat_three(history: Array[String], value: String) -> bool:
	return history.size() >= 2 and history[-1] == value and history[-2] == value

func _push_recent(history: Array[String], value: String) -> void:
	history.append(value)
	while history.size() > 2:
		history.pop_front()
