extends RefCounted

class DamageTarget:
	extends Node2D

	var damage_amounts: Array[int] = []

	func take_contact_damage(amount: int) -> bool:
		damage_amounts.append(amount)
		return true

class InvulnerableTarget:
	extends Node2D

	var attempts: int = 0

	func take_contact_damage(_amount: int) -> bool:
		attempts += 1
		return false

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/enemies/enemy_projectile.gd"):
		runner.assert_true(false, "enemy projectile script should exist")
		return
	var projectile_script = load("res://scripts/enemies/enemy_projectile.gd")
	var projectile = projectile_script.new()
	var sprite := Sprite2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	sprite.name = "Sprite2D"
	collision.name = "CollisionShape2D"
	projectile.add_child(sprite)
	projectile.add_child(collision)
	projectile.sprite = sprite
	projectile.collision_shape = collision

	var releases: Array[Node] = []
	projectile.release_requested.connect(
		func(node: Node) -> void: releases.append(node)
	)
	projectile.activate_from_pool()
	projectile.configure(Vector2(10, 20), Vector2.RIGHT, 330.0, 8, 2.4)
	runner.assert_eq(projectile.global_position, Vector2(10, 20), "projectile should start at configured origin")
	projectile.advance_projectile(0.1)
	runner.assert_near(projectile.global_position.x, 43.0, 0.001, "projectile should move in its locked direction")
	runner.assert_near(projectile.global_position.y, 20.0, 0.001, "projectile should not home vertically")

	var target := DamageTarget.new()
	runner.assert_true(projectile.try_hit(target), "projectile should damage a compatible target")
	runner.assert_eq(target.damage_amounts, [8], "projectile should apply configured damage once")
	runner.assert_eq(releases, [projectile], "successful hit should request one pool release")
	runner.assert_true(not projectile.is_pool_active(), "released projectile should become inactive immediately")
	runner.assert_true(not projectile.try_hit(target), "inactive projectile should not hit again")
	runner.assert_eq(target.damage_amounts, [8], "second overlap should not duplicate damage")

	var invulnerable_target := InvulnerableTarget.new()
	projectile.activate_from_pool()
	projectile.configure(Vector2.ZERO, Vector2.RIGHT, 120.0, 5, 1.0)
	runner.assert_true(
		projectile.try_hit(invulnerable_target),
		"projectile should be consumed by an invulnerable compatible target"
	)
	runner.assert_eq(invulnerable_target.attempts, 1, "invulnerable target should receive one damage attempt")
	runner.assert_eq(releases.size(), 2, "invulnerable overlap should still request release")
	runner.assert_true(not projectile.is_pool_active(), "invulnerable overlap should consume the projectile")

	projectile.activate_from_pool()
	projectile.configure(Vector2.ZERO, Vector2.DOWN, 120.0, 5, 0.2)
	runner.assert_true(projectile.is_pool_active(), "pooled projectile should reactivate")
	runner.assert_eq(projectile.direction, Vector2.DOWN, "reuse should replace the old direction")
	runner.assert_eq(projectile.damage, 5, "reuse should replace the old damage")
	projectile.advance_projectile(0.21)
	runner.assert_eq(releases.size(), 3, "expired projectile should request release")
	runner.assert_true(not projectile.is_pool_active(), "expired projectile should become inactive")

	target.free()
	invulnerable_target.free()
	projectile.free()
