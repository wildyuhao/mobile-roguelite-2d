extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/components/hit_feedback.gd"):
		runner.assert_true(false, "hit feedback component should exist")
		return
	var feedback = load("res://scripts/components/hit_feedback.gd").new()
	var target := Sprite2D.new()
	var spark := Sprite2D.new()
	var label := Label.new()
	target.scale = Vector2(0.72, 0.72)
	spark.scale = Vector2(0.18, 0.18)
	label.position = Vector2(-24, -72)
	runner.assert_true(feedback.configure(target, spark, label), "feedback should configure valid nodes")

	runner.assert_true(feedback.play_hit(8, &"player"), "player profile should start")
	runner.assert_true(feedback.is_playing(), "feedback should report an active hit")
	runner.assert_true(spark.visible, "hit spark should become visible")
	runner.assert_true(label.visible, "player damage label should become visible")
	runner.assert_eq(label.text, "-8", "damage label should show the applied amount")
	runner.assert_true(target.scale.x > 0.72, "player hit should punch target scale")
	feedback._process(0.5)
	runner.assert_true(not feedback.is_playing(), "feedback should finish deterministically")
	runner.assert_true(not spark.visible, "finished spark should hide")
	runner.assert_true(not label.visible, "finished label should hide")
	runner.assert_eq(target.scale, Vector2(0.72, 0.72), "finished feedback should restore target scale")
	runner.assert_eq(target.self_modulate, Color.WHITE, "finished feedback should restore target tint")

	runner.assert_true(feedback.play_hit(5, &"enemy"), "enemy profile should start")
	runner.assert_true(not label.visible, "enemy profile should not show player damage text")
	feedback.reset_feedback()
	runner.assert_true(not feedback.is_playing(), "reset should stop feedback")
	runner.assert_true(not spark.visible, "reset should hide spark")

	feedback.free()
	target.free()
	spark.free()
	label.free()
