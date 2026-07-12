extends RefCounted

const CARDS: Array[Dictionary] = [
	{
		"id": "a",
		"weight": 5,
		"min_time": 0.0,
		"max_time": 999.0,
		"cooldown_draws": 0,
		"pressure_cost": 4,
		"groups": [{"enemy_id": "basic", "count": 4}],
	},
	{
		"id": "b",
		"weight": 3,
		"min_time": 0.0,
		"max_time": 999.0,
		"cooldown_draws": 0,
		"pressure_cost": 5,
		"groups": [{"enemy_id": "charge", "count": 1}],
	},
	{
		"id": "c",
		"weight": 2,
		"min_time": 10.0,
		"max_time": 999.0,
		"cooldown_draws": 1,
		"pressure_cost": 8,
		"groups": [{"enemy_id": "ranged", "count": 2}],
	},
]

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/encounter_bag.gd"):
		runner.assert_true(false, "encounter bag should exist")
		return
	var script = load("res://scripts/systems/encounter_bag.gd")
	var first = script.new()
	var second = script.new()
	first.configure(CARDS, 20260712)
	second.configure(CARDS, 20260712)
	var ids: Array[String] = []
	var signatures: Array[String] = []
	for index in range(30):
		var elapsed := 20.0 + index
		var a: Dictionary = first.draw(elapsed, 8)
		var b: Dictionary = second.draw(elapsed, 8)
		runner.assert_eq(
			a.get("id", ""),
			b.get("id", ""),
			"same seed should produce same draw"
		)
		runner.assert_true(
			int(a.get("pressure_cost", 999)) <= 8,
			"draw should respect budget"
		)
		ids.append(String(a.get("id", "")))
		signatures.append(first.enemy_signature(a))
		if ids.size() >= 3:
			runner.assert_true(
				not (ids[-1] == ids[-2] and ids[-2] == ids[-3]),
				"card should not repeat three times"
			)
			runner.assert_true(
				not (
					signatures[-1] == signatures[-2]
					and signatures[-2] == signatures[-3]
				),
				"enemy signature should not repeat three times"
			)
	var unavailable: Dictionary = first.draw(2.0, 3)
	runner.assert_true(unavailable.is_empty(), "no eligible card should return an empty draw")
