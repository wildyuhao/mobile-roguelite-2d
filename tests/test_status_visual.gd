extends RefCounted

func run(runner) -> void:
	var script_path := "res://scripts/components/status_visual.gd"
	if not ResourceLoader.exists(script_path):
		runner.assert_true(false, "status visual component should exist")
		return

	var visual = load(script_path).new()
	var icon := Sprite2D.new()
	var stack_label := Label.new()
	icon.name = "Icon"
	stack_label.name = "StackLabel"
	visual.add_child(icon)
	visual.add_child(stack_label)
	visual.icon = icon
	visual.stack_label = stack_label
	var burn_texture := _texture(Color.ORANGE_RED)
	var armor_texture := _texture(Color.GOLD)
	var seal_texture := _texture(Color.CYAN)
	var freeze_texture := _texture(Color.LIGHT_BLUE)
	visual.burn_texture = burn_texture
	visual.armor_break_texture = armor_texture
	visual.seal_texture = seal_texture
	visual.freeze_texture = freeze_texture

	visual.apply_snapshot({ "burn": { "stacks": 3 } })
	runner.assert_true(visual.visible, "active status should show one aggregate mark")
	runner.assert_eq(icon.texture, burn_texture, "burn should select its mark")
	runner.assert_eq(stack_label.text, "3", "multiple stacks should use one compact count")

	visual.apply_snapshot({
		"burn": { "stacks": 3 },
		"armor_break": { "stacks": 1 },
		"seal": { "stacks": 1 },
		"freeze": { "stacks": 2 },
	})
	runner.assert_eq(icon.texture, freeze_texture, "freeze should have stable highest priority")
	runner.assert_eq(stack_label.text, "2", "priority mark should show its own stack count")

	visual.apply_snapshot({
		"burn": { "stacks": 2 },
		"armor_break": { "stacks": 1 },
		"seal": { "stacks": 1 },
	})
	runner.assert_eq(icon.texture, seal_texture, "seal should outrank armor break and burn")
	visual.apply_snapshot({
		"burn": { "stacks": 2 },
		"armor_break": { "stacks": 1 },
	})
	runner.assert_eq(icon.texture, armor_texture, "armor break should outrank burn")

	visual.reset_visual()
	runner.assert_true(not visual.visible, "pool reset should hide old status marks")
	runner.assert_eq(stack_label.text, "", "pool reset should clear the stack label")
	visual.free()

	var enemy: Node = load("res://scenes/enemies/BasicDemon.tscn").instantiate()
	var target := Node2D.new()
	enemy.configure({
		"behavior": "chase",
		"max_health": 24,
		"move_speed": 100,
	}, target)
	var enemy_status: Node = enemy.get_node("StatusController")
	var enemy_visual: Node = enemy.get_node("StatusVisual")
	enemy_status.apply_status(
		{ "id": "burn", "stacks": 2, "duration": 3.0 },
		{ "weapon_id": "talisman_fire" }
	)
	runner.assert_true(enemy_visual.visible, "live enemy status should show its aggregate mark")
	enemy.begin_pool_release()
	runner.assert_true(not enemy_visual.visible, "pooled enemy should not retain an old status mark")
	enemy.free()
	target.free()

func _texture(color: Color) -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
