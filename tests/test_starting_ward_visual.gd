extends RefCounted

class WardHost:
	extends Node2D
	var ward_active: bool = true
	var ward_ratio: float = 1.0

	func is_starting_ward_active() -> bool:
		return ward_active

	func get_starting_ward_ratio() -> float:
		return ward_ratio

func run(runner) -> void:
	var script_path := "res://scripts/components/starting_ward_visual.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "starting ward visual component should exist")
		return

	var host := WardHost.new()
	var sprite := Sprite2D.new()
	var visual = load(script_path).new()
	sprite.name = "StartingWardSprite"
	visual.name = "StartingWardVisual"
	host.add_child(sprite)
	host.add_child(visual)
	visual.ward_sprite = sprite

	visual.refresh_visual(0.25)
	runner.assert_true(sprite.visible, "active starting ward should show its sprite")
	runner.assert_true(sprite.rotation > 0.0, "active starting ward should rotate")
	runner.assert_true(sprite.scale != Vector2.ONE, "active starting ward should breathe without moving the player")
	var normal_alpha := sprite.modulate.a

	visual.pulse_time = 0.0
	host.ward_ratio = 0.2
	visual.refresh_visual(0.1)
	runner.assert_true(sprite.modulate.a != normal_alpha, "expiring ward should use a faster warning pulse")
	runner.assert_true(sprite.modulate.a >= 0.5 and sprite.modulate.a <= 1.0, "ward pulse should remain readable")

	host.ward_active = false
	visual.refresh_visual(0.0)
	runner.assert_true(not sprite.visible, "expired starting ward should hide its sprite")
	runner.assert_true(not _contains_collision_shape(visual), "ward visual should not add collision geometry")
	host.free()

func _contains_collision_shape(node: Node) -> bool:
	if node is CollisionShape2D:
		return true
	for child in node.get_children():
		if _contains_collision_shape(child):
			return true
	return false
