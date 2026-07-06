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

	var radius_pickup = pickup_script.new()
	var collision_shape := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = 10.0
	collision_shape.name = "CollisionShape2D"
	collision_shape.shape = circle_shape
	radius_pickup.add_child(collision_shape)
	if radius_pickup.has_method("set_collection_radius_bonus"):
		radius_pickup.set_collection_radius_bonus(24.0)
		runner.assert_near((collision_shape.shape as CircleShape2D).radius, 34.0, 0.001, "pickup radius bonus should enlarge collection shape")
		radius_pickup.set_collection_radius_bonus(0.0)
		runner.assert_near((collision_shape.shape as CircleShape2D).radius, 10.0, 0.001, "empty pickup radius bonus should restore base shape")
	else:
		runner.assert_true(false, "experience pickup should accept collection radius bonuses")
	radius_pickup.free()
