extends Control

signal mission_selected(mission_id: String)

const CampaignProgressionScript = preload("res://scripts/systems/campaign_progression.gd")

const TYPE_LABELS := {
	"survival": "生存",
	"seal": "封印",
	"hunt": "狩猎",
	"mutation": "异变",
	"boss": "首领",
}
const STATE_LABELS := {
	"locked": "未解锁",
	"available": "可挑战",
	"completed": "已完成",
	"mastered": "已精通",
}
const SELECTABLE_STATES := ["available", "completed", "mastered"]

var _materials_label: Label
var _demon_cores_label: Label
var _chapter_list: VBoxContainer
var _mission_name_label: Label
var _mission_description_label: Label
var _mission_rule_label: Label
var _mission_reward_label: Label
var _select_button: Button

var _chapters: Dictionary = {}
var _missions: Dictionary = {}
var _campaign_state: Dictionary = {}
var _chapter_count := 0
var _mission_counts: Dictionary = {}
var _mission_buttons: Dictionary = {}
var _selected_mission_id := ""
var _progression = CampaignProgressionScript.new()

func _ready() -> void:
	_bind_nodes()

func configure(chapters: Dictionary, missions: Dictionary, campaign_state: Dictionary) -> void:
	_bind_nodes()
	_chapters = chapters.duplicate(true)
	_missions = missions.duplicate(true)
	_campaign_state = campaign_state.duplicate(true)
	_chapter_count = 0
	_mission_counts.clear()
	_mission_buttons.clear()
	_selected_mission_id = ""
	for child in _chapter_list.get_children():
		child.free()

	_materials_label.text = "灵石 %d" % int(campaign_state.get("materials", 0))
	var resources: Dictionary = campaign_state.get("resources", {}) if typeof(campaign_state.get("resources")) == TYPE_DICTIONARY else {}
	_demon_cores_label.text = "妖核 %d" % int(campaign_state.get("demon_cores", resources.get("demon_cores", 0)))

	var ordered_chapters: Array = _chapters.values()
	ordered_chapters.sort_custom(func(a, b) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	for chapter_value in ordered_chapters:
		if typeof(chapter_value) == TYPE_DICTIONARY:
			_add_chapter_section(chapter_value)

	var initial_id := String(_campaign_state.get("selected_mission_id", ""))
	if not _missions.has(initial_id):
		initial_id = _find_first_selectable_mission()
	if initial_id != "":
		_show_mission_detail(initial_id)
	else:
		_show_empty_detail()

func _bind_nodes() -> void:
	_materials_label = get_node("MarginContainer/VBoxContainer/Header/MaterialsLabel") as Label
	_demon_cores_label = get_node("MarginContainer/VBoxContainer/Header/DemonCoresLabel") as Label
	_chapter_list = get_node("MarginContainer/VBoxContainer/ChapterScroll/ChapterList") as VBoxContainer
	_mission_name_label = get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/MissionNameLabel") as Label
	_mission_description_label = get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/MissionDescriptionLabel") as Label
	_mission_rule_label = get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/MissionRuleLabel") as Label
	_mission_reward_label = get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/MissionRewardLabel") as Label
	_select_button = get_node("MarginContainer/VBoxContainer/MissionDetail/DetailVBox/SelectButton") as Button
	if not _select_button.pressed.is_connected(_on_select_button_pressed):
		_select_button.pressed.connect(_on_select_button_pressed)

func get_chapter_count() -> int:
	return _chapter_count

func get_mission_count(chapter_id: String) -> int:
	return int(_mission_counts.get(chapter_id, 0))

func get_mission_state(mission_id: String) -> String:
	return _progression.get_mission_state(mission_id, _campaign_state, _missions, _chapters)

func get_mission_button(mission_id: String) -> Button:
	return _mission_buttons.get(mission_id) as Button

func _add_chapter_section(chapter: Dictionary) -> void:
	var chapter_id := String(chapter.get("id", ""))
	var section := VBoxContainer.new()
	section.name = "Chapter_%s" % chapter_id
	section.set_meta("chapter_id", chapter_id)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	_chapter_list.add_child(section)
	_chapter_count += 1

	if bool(chapter.get("implemented", false)):
		_add_implemented_chapter(section, chapter)
	else:
		_add_unavailable_chapter(section, chapter)

func _add_implemented_chapter(section: VBoxContainer, chapter: Dictionary) -> void:
	var title := Label.new()
	title.text = "%02d  %s" % [int(chapter.get("order", 0)), String(chapter.get("display_name", ""))]
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color("e9c96c"))
	section.add_child(title)

	var mission_row := HBoxContainer.new()
	mission_row.name = "MissionRow"
	mission_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_row.add_theme_constant_override("separation", 8)
	section.add_child(mission_row)

	var chapter_id := String(chapter.get("id", ""))
	var ordered_missions: Array = []
	for mission_value in _missions.values():
		if typeof(mission_value) == TYPE_DICTIONARY and String(mission_value.get("chapter_id", "")) == chapter_id:
			ordered_missions.append(mission_value)
	ordered_missions.sort_custom(func(a, b) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	_mission_counts[chapter_id] = ordered_missions.size()
	for mission_value in ordered_missions:
		_add_mission_button(mission_row, mission_value)

func _add_unavailable_chapter(section: VBoxContainer, chapter: Dictionary) -> void:
	var row := Button.new()
	row.name = "UnavailableChapter"
	row.custom_minimum_size = Vector2(0, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.disabled = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "%02d  %s    尚未开放" % [int(chapter.get("order", 0)), String(chapter.get("display_name", ""))]
	row.add_theme_font_size_override("font_size", 18)
	row.add_theme_color_override("font_disabled_color", Color("829092"))
	row.add_theme_stylebox_override("disabled", _make_style(Color("182023"), Color("465255"), 1))
	section.add_child(row)
	_mission_counts[String(chapter.get("id", ""))] = 0

func _add_mission_button(parent: HBoxContainer, mission: Dictionary) -> void:
	var mission_id := String(mission.get("id", ""))
	var state := get_mission_state(mission_id)
	var button := Button.new()
	button.name = "Mission_%s" % mission_id
	button.custom_minimum_size = Vector2(64, 92)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = "%02d\n%s\n%s · %s" % [
		int(mission.get("order", 0)),
		String(mission.get("display_name", "")),
		String(TYPE_LABELS.get(String(mission.get("type", "")), "任务")),
		String(STATE_LABELS.get(state, "未解锁")),
	]
	button.set_meta("mission_id", mission_id)
	button.add_theme_font_size_override("font_size", 15)
	_apply_mission_style(button, state)
	button.pressed.connect(_on_mission_button_pressed.bind(mission_id))
	parent.add_child(button)
	_mission_buttons[mission_id] = button

func _apply_mission_style(button: Button, state: String) -> void:
	var background := Color("182326")
	var border := Color("4ec9cf")
	var font_color := Color("e9f3f2")
	match state:
		"locked":
			background = Color("171d1f")
			border = Color("4b5759")
			font_color = Color("8d999b")
		"completed":
			background = Color("22251f")
			border = Color("c3a653")
			font_color = Color("eadcae")
		"mastered":
			background = Color("293024")
			border = Color("e9c96c")
			font_color = Color("fff0b5")
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	button.add_theme_stylebox_override("normal", _make_style(background, border, 2))
	button.add_theme_stylebox_override("hover", _make_style(background.lightened(0.08), Color("70e4e7"), 2))
	button.add_theme_stylebox_override("pressed", _make_style(background.darkened(0.08), border, 2))
	button.add_theme_stylebox_override("focus", _make_style(background, Color("e9c96c"), 2))

func _on_mission_button_pressed(mission_id: String) -> void:
	_show_mission_detail(mission_id)
	if _is_selectable(mission_id):
		mission_selected.emit(mission_id)

func _on_select_button_pressed() -> void:
	if _is_selectable(_selected_mission_id):
		mission_selected.emit(_selected_mission_id)

func _show_mission_detail(mission_id: String) -> void:
	if not _missions.has(mission_id):
		_show_empty_detail()
		return
	_selected_mission_id = mission_id
	var mission: Dictionary = _missions[mission_id]
	var state := get_mission_state(mission_id)
	_mission_name_label.text = String(mission.get("display_name", "未知任务"))
	_mission_description_label.text = String(mission.get("description", ""))
	_mission_rule_label.text = _get_rule_text(mission, state)
	_mission_reward_label.text = _get_reward_text(mission)
	_select_button.disabled = state == "locked"
	_select_button.text = "尚未解锁" if state == "locked" else "进入任务"

func _show_empty_detail() -> void:
	_selected_mission_id = ""
	_mission_name_label.text = "暂无任务"
	_mission_description_label.text = ""
	_mission_rule_label.text = ""
	_mission_reward_label.text = ""
	_select_button.text = "不可进入"
	_select_button.disabled = true

func _get_rule_text(mission: Dictionary, state: String) -> String:
	if state == "locked":
		var prerequisite_names: Array[String] = []
		for prerequisite_value in Array(mission.get("prerequisites", [])):
			var prerequisite_id := String(prerequisite_value)
			var prerequisite: Dictionary = _missions.get(prerequisite_id, {})
			prerequisite_names.append(String(prerequisite.get("display_name", prerequisite_id)))
		return "前置：完成 %s" % "、".join(prerequisite_names) if not prerequisite_names.is_empty() else "前置：尚未满足"

	var objective: Dictionary = mission.get("objective", {}) if typeof(mission.get("objective")) == TYPE_DICTIONARY else {}
	match String(objective.get("kind", "")):
		"survive":
			return "目标：坚守 %d 分钟" % (int(objective.get("duration", 0)) / 60)
		"seal_points":
			return "目标：守住 %d 处封印点" % int(objective.get("count", 0))
		"elite_hunt":
			return "目标：击败 %d 名精英妖魔" % int(objective.get("count", 0))
		"mutator_survival":
			return "目标：承受异变并坚守 %d 分钟" % (int(objective.get("duration", 0)) / 60)
		"boss":
			return "目标：击败封印首领"
	return "目标：完成任务"

func _get_reward_text(mission: Dictionary) -> String:
	var first_reward: Dictionary = mission.get("first_reward", {})
	var repeat_reward: Dictionary = mission.get("repeat_reward", {})
	return "首胜：%s    重复：%s" % [_format_reward(first_reward), _format_reward(repeat_reward)]

func _format_reward(reward: Dictionary) -> String:
	var text := "灵石 %d" % int(reward.get("materials", 0))
	var demon_cores := int(reward.get("demon_cores", 0))
	if demon_cores > 0:
		text += " · 妖核 %d" % demon_cores
	return text

func _find_first_selectable_mission() -> String:
	var ordered_missions: Array = _missions.values()
	ordered_missions.sort_custom(func(a, b) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	for mission_value in ordered_missions:
		var mission_id := String(mission_value.get("id", ""))
		if _is_selectable(mission_id):
			return mission_id
	return ""

func _is_selectable(mission_id: String) -> bool:
	return mission_id != "" and get_mission_state(mission_id) in SELECTABLE_STATES

func _make_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
