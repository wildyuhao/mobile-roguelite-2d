extends RefCounted

const SCENE_PATH := "res://scenes/ui/CharacterSelect.tscn"
const MECHANISM_WALKER_ID := "mechanism_walker"

func run(runner) -> void:
	if not ResourceLoader.exists(SCENE_PATH):
		runner.assert_true(false, "character selection scene should exist")
		return

	var battle_db = load("res://scripts/data/game_database.gd").new()
	runner.assert_true(battle_db.load_all(), "battle catalog should load before character selection")
	var catalog = load("res://scripts/data/content_catalog.gd").new()
	runner.assert_true(catalog.load_all(battle_db), "content catalog should load before character selection")
	var default_save: Dictionary = load("res://scripts/systems/save_system.gd").new().create_default_save()
	var characters_state: Dictionary = default_save["characters"].duplicate(true)
	characters_state["mastery_levels"][MECHANISM_WALKER_ID] = 1
	characters_state["mastery_experience"][MECHANISM_WALKER_ID] = 40
	var mission: Dictionary = catalog.get_mission("red_wastes_survival")

	var viewport_host := Control.new()
	viewport_host.size = Vector2(720, 1280)
	Engine.get_main_loop().root.add_child(viewport_host)
	var selection = load(SCENE_PATH).instantiate()
	runner.assert_eq(
		Vector4(selection.anchor_left, selection.anchor_top, selection.anchor_right, selection.anchor_bottom),
		Vector4(0, 0, 1, 1),
		"character selection should use full-viewport anchors",
	)
	selection.set_anchors_preset(Control.PRESET_TOP_LEFT)
	selection.size = viewport_host.size
	viewport_host.add_child(selection)
	selection.configure(mission, catalog.get_characters(), characters_state, battle_db.get_weapons())

	runner.assert_eq(selection.size, Vector2(720, 1280), "character selection should fill a 720 x 1280 viewport")
	runner.assert_eq(selection.get_selected_character_id(), MECHANISM_WALKER_ID, "default unlocked character should be selected")
	runner.assert_true(selection.is_start_enabled(), "default unlocked character should be startable")
	var screen_text := _collect_text(selection)
	runner.assert_true("荒境守望" in screen_text, "selection header should show the selected mission")
	runner.assert_true("机关行者" in screen_text, "selection should show the formal character name")
	runner.assert_true("Lv.1" in screen_text, "selection should show mastery level one")
	runner.assert_true("40 / 100" in screen_text, "selection should show progress toward the next mastery threshold")
	runner.assert_true("机关连弩" in screen_text, "selection should resolve the formal starting weapon name from injected definitions")
	for tag in ["均衡", "机关", "投射物"]:
		runner.assert_true(tag in screen_text, "selection should show the %s build tag" % tag)

	var portrait: TextureRect = selection.get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/Portrait")
	runner.assert_true(portrait.texture != null, "character detail should show a portrait")
	if portrait.texture != null:
		runner.assert_eq(portrait.texture.resource_path, "res://art/characters/player/player_front.png", "character selection should reuse the formal player portrait")
	runner.assert_true(portrait.custom_minimum_size.x <= 240.0, "portrait should be no wider than 240 logical pixels")
	runner.assert_true(portrait.custom_minimum_size.y <= 320.0, "portrait should be no taller than 320 logical pixels")
	runner.assert_true((portrait.size_flags_vertical & Control.SIZE_EXPAND) == 0, "portrait should not expand beyond 320 logical pixels")
	runner.assert_eq(portrait.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "portrait should ignore its source size")
	runner.assert_eq(portrait.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "portrait should keep aspect ratio and remain centered")
	var mastery_bar: ProgressBar = selection.get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/MasteryBar")
	runner.assert_eq(mastery_bar.min_value, 0.0, "mastery progress should be relative to the current level")
	runner.assert_eq(mastery_bar.max_value, 100.0, "level one mastery should target the 100 XP threshold")
	runner.assert_eq(mastery_bar.value, 40.0, "mastery bar should show current level progress")

	var back_button: Button = selection.get_node("MarginContainer/VBoxContainer/Header/BackButton")
	var start_button: Button = selection.get_node("MarginContainer/VBoxContainer/StartButton")
	runner.assert_true(back_button.custom_minimum_size.y >= 56.0, "back button should be at least 56 pixels high")
	runner.assert_true(start_button.custom_minimum_size.y >= 56.0, "primary start button should be at least 56 pixels high")
	var character_button: Button = selection.get_character_button(MECHANISM_WALKER_ID)
	runner.assert_true(character_button != null, "selection should expose the character button")
	if character_button != null:
		runner.assert_true(character_button.custom_minimum_size.y >= 56.0, "character button should be at least 56 pixels high")

	var started_ids: Array[String] = []
	var back_count := [0]
	selection.start_requested.connect(func(character_id: String) -> void: started_ids.append(character_id))
	selection.back_requested.connect(func() -> void: back_count[0] += 1)
	selection.configure(mission, catalog.get_characters(), characters_state, battle_db.get_weapons())
	runner.assert_eq(
		selection.get_node("MarginContainer/VBoxContainer/CharacterScroll/CharacterList").get_child_count(),
		catalog.get_characters().size(),
		"repeated configure should not duplicate character buttons",
	)
	start_button.pressed.emit()
	back_button.pressed.emit()
	runner.assert_eq(started_ids, [MECHANISM_WALKER_ID], "repeated configure should still emit start exactly once")
	runner.assert_eq(back_count[0], 1, "back button should emit back_requested exactly once")

	var locked_character: Dictionary = catalog.get_character(MECHANISM_WALKER_ID).duplicate(true)
	locked_character["id"] = "locked_walker"
	locked_character["display_name"] = "锁定行者"
	var characters_with_locked: Dictionary = catalog.get_characters().duplicate(true)
	characters_with_locked["locked_walker"] = locked_character
	selection.configure(mission, characters_with_locked, characters_state, battle_db.get_weapons())
	var locked_button: Button = selection.get_character_button("locked_walker")
	runner.assert_true(locked_button != null, "locked fixture should expose its character button")
	if locked_button != null:
		locked_button.pressed.emit()
	runner.assert_eq(selection.get_selected_character_id(), "locked_walker", "locked character should remain inspectable")
	runner.assert_true(not selection.is_start_enabled(), "locked character should disable the start action")
	runner.assert_true(start_button.disabled, "locked character should disable the primary button")
	start_button.pressed.emit()
	runner.assert_eq(started_ids, [MECHANISM_WALKER_ID], "locked character should emit no start request")

	selection.configure(mission, catalog.get_characters(), characters_state)
	runner.assert_true("mechanism_crossbow" in _collect_text(selection), "three-argument configure should fall back to the starting weapon ID")

	viewport_host.queue_free()

func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += String(node.text)
	for child in node.get_children():
		result += _collect_text(child)
	return result
