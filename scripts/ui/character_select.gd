extends Control

signal start_requested(character_id: String)
signal back_requested

const CharacterProgressionScript = preload("res://scripts/systems/character_progression.gd")
const MASTERY_THRESHOLDS := CharacterProgressionScript.EXPERIENCE_THRESHOLDS

var _mission_label: Label
var _character_list: HBoxContainer
var _portrait: TextureRect
var _name_label: Label
var _mastery_label: Label
var _mastery_bar: ProgressBar
var _weapon_label: Label
var _talent_label: Label
var _tags_label: Label
var _start_button: Button
var _back_button: Button

var _characters: Dictionary = {}
var _characters_state: Dictionary = {}
var _weapon_definitions: Dictionary = {}
var _character_buttons: Dictionary = {}
var _selected_character_id := ""

func _ready() -> void:
	_bind_nodes()

func configure(
	mission: Dictionary,
	characters: Dictionary,
	characters_state: Dictionary,
	weapon_definitions: Dictionary = {},
) -> void:
	_bind_nodes()
	_characters = characters.duplicate(true)
	_characters_state = characters_state.duplicate(true)
	_weapon_definitions = weapon_definitions.duplicate(true)
	_selected_character_id = ""
	_character_buttons.clear()
	for child in _character_list.get_children():
		child.free()

	_mission_label.text = String(mission.get("display_name", "未知任务"))
	var ordered_characters: Array = _characters.values()
	ordered_characters.sort_custom(
		func(a, b) -> bool:
			return String(a.get("display_name", "")) < String(b.get("display_name", ""))
	)
	for character_value in ordered_characters:
		if typeof(character_value) == TYPE_DICTIONARY:
			_add_character_button(character_value)

	var initial_id := String(_characters_state.get("selected_id", ""))
	if not _characters.has(initial_id):
		initial_id = _find_first_unlocked_character(ordered_characters)
	if initial_id == "" and not ordered_characters.is_empty():
		initial_id = String(ordered_characters[0].get("id", ""))
	if initial_id != "":
		_show_character_detail(initial_id)
	else:
		_show_empty_detail()

func get_selected_character_id() -> String:
	return _selected_character_id

func get_character_button(character_id: String) -> Button:
	return _character_buttons.get(character_id) as Button

func is_start_enabled() -> bool:
	return _start_button != null and not _start_button.disabled

func _bind_nodes() -> void:
	_back_button = get_node("MarginContainer/VBoxContainer/Header/BackButton") as Button
	_mission_label = get_node("MarginContainer/VBoxContainer/Header/MissionLabel") as Label
	_character_list = get_node("MarginContainer/VBoxContainer/CharacterScroll/CharacterList") as HBoxContainer
	_portrait = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/Portrait") as TextureRect
	_name_label = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/NameLabel") as Label
	_mastery_label = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/MasteryLabel") as Label
	_mastery_bar = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/MasteryBar") as ProgressBar
	_weapon_label = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/WeaponLabel") as Label
	_talent_label = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/TalentLabel") as Label
	_tags_label = get_node("MarginContainer/VBoxContainer/CharacterDetail/DetailVBox/TagsLabel") as Label
	_start_button = get_node("MarginContainer/VBoxContainer/StartButton") as Button
	if not _back_button.pressed.is_connected(_on_back_button_pressed):
		_back_button.pressed.connect(_on_back_button_pressed)
	if not _start_button.pressed.is_connected(_on_start_button_pressed):
		_start_button.pressed.connect(_on_start_button_pressed)

func _add_character_button(character: Dictionary) -> void:
	var character_id := String(character.get("id", ""))
	if character_id == "":
		return
	var button := Button.new()
	button.name = "Character_%s" % character_id
	button.custom_minimum_size = Vector2(180, 64)
	button.toggle_mode = true
	button.text = "%s\n%s" % [
		String(character.get("display_name", character_id)),
		"已解锁" if _is_unlocked(character_id) else "未解锁",
	]
	button.set_meta("character_id", character_id)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("e9f3f2"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("fff0b5"))
	button.add_theme_stylebox_override("normal", _make_button_style(Color("182326"), Color("46575a")))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("203235"), Color("4ec9cf")))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("293024"), Color("e9c96c")))
	button.add_theme_stylebox_override("focus", _make_button_style(Color("182326"), Color("e9c96c")))
	button.pressed.connect(_on_character_button_pressed.bind(character_id))
	_character_list.add_child(button)
	_character_buttons[character_id] = button

func _on_character_button_pressed(character_id: String) -> void:
	_show_character_detail(character_id)

func _on_start_button_pressed() -> void:
	if _selected_character_id != "" and _characters.has(_selected_character_id) and _is_unlocked(_selected_character_id):
		start_requested.emit(_selected_character_id)

func _on_back_button_pressed() -> void:
	back_requested.emit()

func _show_character_detail(character_id: String) -> void:
	if not _characters.has(character_id):
		_show_empty_detail()
		return
	_selected_character_id = character_id
	for id in _character_buttons:
		var character_button: Button = _character_buttons[id]
		character_button.set_pressed_no_signal(String(id) == character_id)

	var character: Dictionary = _characters[character_id]
	_name_label.text = String(character.get("display_name", character_id))
	_set_portrait(String(character.get("portrait_path", "")))
	_set_mastery(character_id)
	var weapon_id := String(character.get("starting_weapon_id", ""))
	var weapon: Dictionary = _weapon_definitions.get(weapon_id, {})
	_weapon_label.text = "初始武器 · %s" % String(weapon.get("display_name", weapon_id))
	var talent_display_name := String(character.get("innate_talent_display_name", "")).strip_edges()
	_talent_label.text = "天赋 · %s" % (talent_display_name if talent_display_name != "" else "未配置")
	var tags: Array[String] = []
	for tag in Array(character.get("build_tags", [])):
		tags.append(String(tag))
	_tags_label.text = "流派标签 · %s" % " · ".join(tags)
	_start_button.disabled = not _is_unlocked(character_id)
	_start_button.text = "开始修行" if not _start_button.disabled else "尚未解锁"

func _set_portrait(portrait_path: String) -> void:
	_portrait.texture = null
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path) as Texture2D

func _set_mastery(character_id: String) -> void:
	var levels: Dictionary = _get_state_dictionary("mastery_levels")
	var experience_by_character: Dictionary = _get_state_dictionary("mastery_experience")
	var level := clampi(int(levels.get(character_id, 1)), 1, MASTERY_THRESHOLDS.size())
	var experience := maxi(0, int(experience_by_character.get(character_id, 0)))
	var current_threshold: int = MASTERY_THRESHOLDS[level - 1]
	if level >= MASTERY_THRESHOLDS.size():
		_mastery_label.text = "熟练度 · Lv.%d    已满级" % level
		_mastery_bar.min_value = 0.0
		_mastery_bar.max_value = 1.0
		_mastery_bar.value = 1.0
		return
	var next_threshold: int = MASTERY_THRESHOLDS[level]
	var required := next_threshold - current_threshold
	var progress := clampi(experience - current_threshold, 0, required)
	_mastery_label.text = "熟练度 · Lv.%d    %d / %d" % [level, progress, required]
	_mastery_bar.min_value = 0.0
	_mastery_bar.max_value = float(required)
	_mastery_bar.value = float(progress)

func _get_state_dictionary(key: String) -> Dictionary:
	var value = _characters_state.get(key, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _find_first_unlocked_character(ordered_characters: Array) -> String:
	for character_value in ordered_characters:
		var character_id := String(character_value.get("id", ""))
		if _is_unlocked(character_id):
			return character_id
	return ""

func _is_unlocked(character_id: String) -> bool:
	var unlocked_ids = _characters_state.get("unlocked_ids", [])
	return typeof(unlocked_ids) == TYPE_ARRAY and Array(unlocked_ids).has(character_id)

func _show_empty_detail() -> void:
	_selected_character_id = ""
	_portrait.texture = null
	_name_label.text = "暂无角色"
	_mastery_label.text = "熟练度 · Lv.1"
	_mastery_bar.min_value = 0.0
	_mastery_bar.max_value = 1.0
	_mastery_bar.value = 0.0
	_weapon_label.text = "初始武器 · 未配置"
	_talent_label.text = "天赋 · 未配置"
	_tags_label.text = "流派标签 · 未配置"
	_start_button.text = "不可开始"
	_start_button.disabled = true

func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
