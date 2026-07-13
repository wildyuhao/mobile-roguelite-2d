# Mobile Upgrade Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让竖屏升级选项通过正式图标、升级类别和当前进度实现快速扫读，同时保留现有三个大按钮和升级逻辑。

**Architecture:** 核心升级 JSON 显式绑定正式图标；`UpgradeSystem` 从当局状态计算类别与进度；`UpgradeChoicePanel` 只负责加载纹理和渲染三行按钮文本。缺图时回退为纯文字并清除复用按钮上的旧图标。

**Tech Stack:** Godot 4.7、GDScript、JSON 数据、现有 PNG 正式图标。

## Global Constraints

- 不修改升级概率、数值、升级池、随机种子或暂停逻辑。
- 三个按钮的最小触控高度必须不低于 116 逻辑像素。
- 图标最大宽度固定为 68 逻辑像素，文字字号固定为 17。
- 不生成新素材，不增加稀有度系统或新的运行时节点类型。
- 所有行为修改先写失败测试，再写最小实现。

---

### Task 1: 核心升级正式图标绑定

**Files:**
- Modify: `tests/test_game_database.gd`
- Modify: `data/upgrades/core_upgrades.json`

**Interfaces:**
- Produces: every core upgrade dictionary contains `icon_path: String`
- Produces: every `icon_path` resolves to a `Texture2D`

- [ ] **Step 1: Write the failing database test**

在数据库升级循环中加入：

```gdscript
var icon_path := String(upgrade.get("icon_path", ""))
runner.assert_true(icon_path != "", "%s should define an upgrade icon" % upgrade_id)
runner.assert_true(ResourceLoader.exists(icon_path), "%s icon should exist" % upgrade_id)
if ResourceLoader.exists(icon_path):
	runner.assert_true(load(icon_path) is Texture2D, "%s icon should load as a texture" % upgrade_id)
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
& $godot --headless --path . --script res://tests/run_all_tests.gd
```

Expected: FAIL because existing upgrades have no `icon_path`.

- [ ] **Step 3: Add explicit icon paths**

Add `icon_path` to every object in `core_upgrades.json` using these exact mappings:

```text
weapon_damage_1, heavy_seal, wind_edge -> res://art/icons/icon_flying_sword.png
cooldown_1, quickstep_invocation, gathering_breath -> res://art/icons/icon_jade_compass.png
pickup_radius_1, prosperity_compass -> res://art/icons/icon_spirit_stone.png
move_speed_1 -> res://art/icons/icon_mechanism_part.png
max_health_1, iron_focus -> res://art/icons/icon_talisman_paper.png
flying_sword_level -> res://art/icons/icon_flying_sword.png
talisman_fire_level, unlock_talisman_fire -> res://art/icons/icon_talisman_fire.png
mechanism_crossbow_level, unlock_mechanism_crossbow -> res://art/icons/icon_mechanism_crossbow.png
demon_sealing_bell_level, unlock_demon_sealing_bell -> res://art/icons/icon_demon_sealing_bell.png
spirit_needle_array_level, unlock_spirit_needle_array -> res://art/icons/icon_spirit_needle_array.png
unlock_sword_gourd_blades, sword_gourd_blades_level -> res://art/weapons/sword_gourd/sword_gourd_icon.png
unlock_frost_talisman, frost_talisman_level -> res://art/weapons/frost_talisman/frost_talisman_icon.png
unlock_soul_lantern, soul_lantern_level -> res://art/weapons/soul_lantern/soul_lantern_icon.png
```

- [ ] **Step 4: Run test to verify it passes**

Run the full Godot test command. Expected: `All tests passed.`

- [ ] **Step 5: Commit**

```powershell
git add data/upgrades/core_upgrades.json tests/test_game_database.gd
git commit -m "data: bind upgrade choice icons"
```

### Task 2: 升级类别与当局进度元数据

**Files:**
- Modify: `tests/test_upgrade_system.gd`
- Modify: `scripts/systems/upgrade_system.gd`

**Interfaces:**
- Produces: `category_label: String` on every returned choice
- Produces: `progress_label: String` on every returned choice
- Preserves: `get_choices(runtime_state, count, seed_value) -> Array[Dictionary]`

- [ ] **Step 1: Write the failing presentation metadata test**

Configure four upgrades and request all four from this state:

```gdscript
var presentation_system = upgrade_system_script.new()
presentation_system.configure([
	{"id": "weapon_damage_1", "display_name": "锋刃淬炼", "kind": "stat", "stat": "weapon_damage_multiplier", "value": 0.15, "max_stacks": 5},
	{"id": "quickstep_invocation", "display_name": "疾行敕令", "kind": "stat_bundle", "stat_modifiers": {"move_speed": 12}, "max_stacks": 3},
	{"id": "flying_sword_level", "display_name": "飞剑精进", "kind": "weapon_level", "weapon_id": "flying_sword", "max_stacks": 4},
	{"id": "unlock_frost_talisman", "display_name": "习得寒霜符", "kind": "weapon_unlock", "weapon_id": "frost_talisman", "max_stacks": 1},
])
var presentation_state := {
	"owned_weapons": {"flying_sword": 2, "talisman_fire": 1},
	"upgrade_stacks": {"weapon_damage_1": 1},
	"max_weapon_slots": 4,
}
var presentation_choices := presentation_system.get_choices(presentation_state, 4, 2718)
runner.assert_eq(_find_choice(presentation_choices, "unlock_frost_talisman").get("category_label", ""), "新武器", "unlock should identify its category")
runner.assert_eq(_find_choice(presentation_choices, "unlock_frost_talisman").get("progress_label", ""), "Lv.1", "unlock should show its starting level")
runner.assert_eq(_find_choice(presentation_choices, "flying_sword_level").get("category_label", ""), "武器精进", "weapon level should identify its category")
runner.assert_eq(_find_choice(presentation_choices, "flying_sword_level").get("progress_label", ""), "Lv.2→3", "weapon level should show current and next level")
runner.assert_eq(_find_choice(presentation_choices, "weapon_damage_1").get("progress_label", ""), "第2重", "stacked stat should show the level being selected")
runner.assert_eq(_find_choice(presentation_choices, "quickstep_invocation").get("category_label", ""), "组合功法", "bundle should identify its category")
runner.assert_eq(_find_choice(presentation_choices, "quickstep_invocation").get("progress_label", ""), "第1重", "fresh bundle should show its first layer")
presentation_system.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run the full Godot test command. Expected: FAIL because choices have no category or progress metadata.

- [ ] **Step 3: Enrich every returned choice**

Replace both `_with_effect_summary(...)` calls in `get_choices()` with `_with_presentation(upgrade, runtime_state)` and add:

```gdscript
func _with_presentation(upgrade: Dictionary, runtime_state: Dictionary) -> Dictionary:
	var result := _with_effect_summary(upgrade)
	var kind := String(result.get("kind", ""))
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})
	match kind:
		"weapon_unlock":
			result["category_label"] = "新武器"
			result["progress_label"] = "Lv.1"
		"weapon_level":
			result["category_label"] = "武器精进"
			var owned_weapons: Dictionary = runtime_state.get("owned_weapons", {})
			var current_level := int(owned_weapons.get(String(result.get("weapon_id", "")), 1))
			result["progress_label"] = "Lv.%d→%d" % [current_level, current_level + 1]
		"stat_bundle":
			result["category_label"] = "组合功法"
			result["progress_label"] = "第%d重" % (int(stacks.get(String(result.get("id", "")), 0)) + 1)
		_:
			result["category_label"] = "功法强化"
			result["progress_label"] = "第%d重" % (int(stacks.get(String(result.get("id", "")), 0)) + 1)
	return result
```

- [ ] **Step 4: Run test to verify it passes**

Run the full Godot test command. Expected: `All tests passed.`

- [ ] **Step 5: Commit**

```powershell
git add scripts/systems/upgrade_system.gd tests/test_upgrade_system.gd
git commit -m "feat: describe upgrade choice progress"
```

### Task 3: 图标化移动升级按钮

**Files:**
- Modify: `tests/test_upgrade_choice_panel.gd`
- Modify: `scripts/ui/upgrade_choice_panel.gd`
- Modify: `scenes/ui/UpgradeChoicePanel.tscn`

**Interfaces:**
- Consumes: `icon_path`, `category_label`, `progress_label`, `display_name`, `effect_summary`
- Preserves: `show_choices(choices: Array[Dictionary]) -> void`
- Preserves: `upgrade_selected(upgrade: Dictionary)`

- [ ] **Step 1: Write the failing panel test**

Pass one valid icon, one missing icon and one second valid icon. Assert:

```gdscript
runner.assert_eq(button1.text, "功法强化 · 第2重\n锋刃淬炼\n伤害 +15%", "choice should expose category, progress, name and effect")
runner.assert_true(button1.icon is Texture2D, "valid choice icon should load")
runner.assert_eq(button2.icon, null, "invalid icon should fall back to text only")
runner.assert_true(button1.custom_minimum_size.y >= 116.0, "choice should remain a mobile touch target")
runner.assert_true(button1.expand_icon, "choice icon should scale inside its bound")
runner.assert_eq(button1.get_theme_constant("icon_max_width"), 68, "choice icon should have a stable width")
runner.assert_eq(button1.alignment, HORIZONTAL_ALIGNMENT_LEFT, "choice text should scan from the left")
panel.show_choices([])
runner.assert_eq(button1.icon, null, "button reuse should clear stale icons")
```

- [ ] **Step 2: Run test to verify it fails**

Run the full Godot test command. Expected: FAIL because buttons do not load icons or render presentation metadata.

- [ ] **Step 3: Implement texture loading and three-line text**

Add an `icon_cache` dictionary and use this implementation shape:

```gdscript
var icon_cache: Dictionary = {}

func _load_choice_icon(choice: Dictionary) -> Texture2D:
	var icon_path := String(choice.get("icon_path", ""))
	if icon_path == "" or not ResourceLoader.exists(icon_path):
		return null
	if icon_cache.has(icon_path):
		return icon_cache[icon_path]
	var texture = load(icon_path)
	if texture is Texture2D:
		icon_cache[icon_path] = texture
		return texture
	return null
```

In `show_choices()`, assign `button.icon = _load_choice_icon(choice)` for available choices and `button.icon = null` for missing choices. Format text as category/progress header, name, then optional summary.

- [ ] **Step 4: Update the scene layout**

Set the panel offsets to top `250`, bottom `850`; set every button to minimum height `116`, font size `17`, left text alignment, `expand_icon = true`, `theme_override_constants/icon_max_width = 68`, `clip_text = true`, and ellipsis overrun behavior.

- [ ] **Step 5: Run automated and visual verification**

```powershell
& $godot --headless --editor --path . --quit
& $godot --headless --path . --script res://tests/run_all_tests.gd
& $godot --headless --path . --quit-after 600
```

Then launch at `390x844`, trigger the first upgrade and confirm three readable icon rows with no overlap or stale textures.

- [ ] **Step 6: Commit and push**

```powershell
git add scripts/ui/upgrade_choice_panel.gd scenes/ui/UpgradeChoicePanel.tscn tests/test_upgrade_choice_panel.gd
git commit -m "feat: improve mobile upgrade choices"
git push origin main
```
