extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/pickups/experience_pickup.gd"):
		runner.assert_true(false, "experience pickup script should exist")
		return

	var pickup_script = load("res://scripts/pickups/experience_pickup.gd")
	var pickup = pickup_script.new()
	var collected_amounts: Array[int] = []
	pickup.collected.connect(func(amount: int) -> void: collected_amounts.append(amount))

	pickup.configure(5)
	runner.assert_eq(pickup.experience_value, 5, "configure should set experience value")

	pickup.collect()
	pickup.collect()
	runner.assert_eq(collected_amounts.size(), 1, "pickup should collect only once")
	runner.assert_eq(collected_amounts[0], 5, "pickup should emit configured experience")
	pickup.free()
