extends RefCounted

const EXPECTED_CHAPTER_IDS := [
	"red_wastes",
	"bamboo_ruins",
	"ghost_market",
	"underworld_tomb",
	"thunder_altar",
	"rift_seal_platform",
]
const EXPECTED_MISSION_IDS := [
	"red_wastes_survival",
	"red_wastes_seal",
	"red_wastes_hunt",
	"red_wastes_mutation",
	"red_wastes_boss",
]

func run(runner) -> void:
	if not ResourceLoader.exists("res://scenes/ui/CampaignMap.tscn"):
		runner.assert_true(false, "campaign map scene should exist")
		return

	var battle_db = load("res://scripts/data/game_database.gd").new()
	runner.assert_true(battle_db.load_all(), "battle catalog should load before the campaign map")
	var catalog = load("res://scripts/data/content_catalog.gd").new()
	runner.assert_true(catalog.load_all(battle_db), "campaign catalog should load before the campaign map")
	var default_save: Dictionary = load("res://scripts/systems/save_system.gd").new().create_default_save()

	var viewport_host := Control.new()
	viewport_host.size = Vector2(720, 1280)
	Engine.get_main_loop().root.add_child(viewport_host)
	var map = load("res://scenes/ui/CampaignMap.tscn").instantiate()
	runner.assert_eq(Vector4(map.anchor_left, map.anchor_top, map.anchor_right, map.anchor_bottom), Vector4(0, 0, 1, 1), "campaign map should use full-viewport anchors")
	map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map.size = viewport_host.size
	viewport_host.add_child(map)
	map.configure(catalog.get_chapters(), catalog.get_missions(), default_save["campaign"])

	runner.assert_eq(map.size, Vector2(720, 1280), "campaign map should fill a 720 x 1280 viewport")
	runner.assert_eq(map.get_chapter_count(), 6, "campaign map should show six regions")
	runner.assert_eq(map.get_mission_count("red_wastes"), 5, "Red Wastes should show five mission nodes")
	runner.assert_eq(map.get_mission_state("red_wastes_survival"), "available", "default mission should be available")
	runner.assert_eq(map.get_mission_state("red_wastes_seal"), "locked", "next mission should remain locked")

	var chapter_list: VBoxContainer = map.get_node("MarginContainer/VBoxContainer/ChapterScroll/ChapterList")
	var chapter_ids: Array[String] = []
	for chapter_section in chapter_list.get_children():
		chapter_ids.append(String(chapter_section.get_meta("chapter_id", "")))
	runner.assert_eq(chapter_ids, EXPECTED_CHAPTER_IDS, "campaign chapters should follow numeric order")

	var mission_ids: Array[String] = []
	for child in map.get_mission_button("red_wastes_survival").get_parent().get_children():
		if child is Button:
			mission_ids.append(String(child.get_meta("mission_id", "")))
	runner.assert_eq(mission_ids, EXPECTED_MISSION_IDS, "Red Wastes missions should follow numeric order")

	var survival_button: Button = map.get_mission_button("red_wastes_survival")
	var seal_button: Button = map.get_mission_button("red_wastes_seal")
	runner.assert_true(survival_button != null, "available mission should expose its button")
	runner.assert_true(seal_button != null, "locked mission should expose its button")
	if survival_button != null:
		runner.assert_true(survival_button.custom_minimum_size.x >= 64.0, "mission touch target should be at least 64 pixels wide")
		runner.assert_true(survival_button.custom_minimum_size.y >= 64.0, "mission touch target should be at least 64 pixels high")
		runner.assert_true("荒境守望" in survival_button.text, "mission button should use the formal Chinese name")
		runner.assert_true("生存" in survival_button.text and "可挑战" in survival_button.text, "mission button should show Chinese type and state labels")
	var select_button: Button = map.get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/SelectButton")
	runner.assert_true(select_button.custom_minimum_size.y >= 56.0, "primary select button should be at least 56 pixels high")

	var wasteland_texture: TextureRect = map.get_node("WastelandTexture")
	runner.assert_true(wasteland_texture.texture != null, "campaign map should show the wasteland texture")
	if wasteland_texture.texture != null:
		runner.assert_eq(wasteland_texture.texture.resource_path, "res://art/environment/wasteland_ground_tile.png", "campaign map should reuse the formal wasteland asset")
	var bamboo_section: Control = chapter_list.get_child(1)
	runner.assert_true("幽竹残林" in _collect_text(bamboo_section), "unimplemented chapter should retain its formal name")
	runner.assert_true("尚未开放" in _collect_text(bamboo_section), "unimplemented chapter should use correct Chinese unavailable copy")

	var emitted_ids: Array[String] = []
	map.mission_selected.connect(func(mission_id: String) -> void: emitted_ids.append(mission_id))
	survival_button.pressed.emit()
	runner.assert_eq(map.get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/MissionNameLabel").text, "荒境守望", "available mission should populate the detail view")
	runner.assert_eq(emitted_ids, ["red_wastes_survival"], "available mission button should emit exactly once")
	select_button.pressed.emit()
	runner.assert_eq(emitted_ids, ["red_wastes_survival", "red_wastes_survival"], "select button should emit the current available mission")
	seal_button.pressed.emit()
	runner.assert_true(select_button.disabled, "locked mission should disable the select button")
	runner.assert_true("荒境守望" in map.get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/MissionRuleLabel").text, "locked mission should show its prerequisite")
	select_button.pressed.emit()
	runner.assert_eq(emitted_ids, ["red_wastes_survival", "red_wastes_survival"], "locked mission should not emit mission_selected")

	viewport_host.queue_free()

func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label or node is Button:
		result += String(node.text)
	for child in node.get_children():
		result += _collect_text(child)
	return result
