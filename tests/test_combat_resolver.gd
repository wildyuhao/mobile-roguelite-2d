extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/combat_resolver.gd"):
		runner.assert_true(false, "combat resolver script should exist")
		return

	var resolver_script = load("res://scripts/systems/combat_resolver.gd")
	var resolver = resolver_script.new()
	var origin := Vector2.ZERO
	var near_enemy := Node2D.new()
	var far_enemy := Node2D.new()
	var out_of_range_enemy := Node2D.new()
	near_enemy.global_position = Vector2(40, 0)
	far_enemy.global_position = Vector2(90, 0)
	out_of_range_enemy.global_position = Vector2(180, 0)

	var enemies := [far_enemy, out_of_range_enemy, near_enemy]
	var closest = resolver.find_closest_enemy(origin, enemies, 120.0)
	runner.assert_eq(closest, near_enemy, "resolver should pick the closest enemy inside range")

	var enemies_in_radius = resolver.get_enemies_in_radius(origin, enemies, 100.0)
	runner.assert_eq(enemies_in_radius.size(), 2, "resolver should return enemies inside radius")

	var directions = resolver.build_spread_directions(Vector2.RIGHT, 3, 8.0)
	runner.assert_eq(directions.size(), 3, "resolver should build one direction per projectile")
	runner.assert_near(directions[1].angle(), 0.0, 0.001, "middle projectile should keep base direction")

	if resolver.has_method("build_radial_directions"):
		var radial_directions = resolver.build_radial_directions(4, 0.0)
		runner.assert_eq(radial_directions.size(), 4, "resolver should build one radial direction per projectile")
		runner.assert_eq(radial_directions[0], Vector2.RIGHT, "radial pattern should honor its start angle")
		runner.assert_near(radial_directions[1].angle(), PI / 2.0, 0.001, "radial directions should be evenly spaced")
	else:
		runner.assert_true(false, "resolver should build radial projectile directions")

	near_enemy.free()
	far_enemy.free()
	out_of_range_enemy.free()
