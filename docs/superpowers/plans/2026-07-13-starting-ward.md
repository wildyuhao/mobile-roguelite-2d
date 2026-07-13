# Starting Ward Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给每局前 6 秒增加可见的护身真气，在不减少怪物和刷怪速度的前提下保护触屏玩家完成首次走位。

**Architecture:** `PlayerController` 独立维护保护倒计时并作为敌方伤害的唯一门禁；`StartingWardVisual` 只读取控制器暴露的状态比例并控制阵纹表现。`Player.tscn` 组合正式 image-2 纹理和组件，敌人、波次与游戏循环保持不变。

**Tech Stack:** Godot 4.7、GDScript、Godot 场景资源、image-2、现有绿色幕布提取工具。

## Global Constraints

- `starting_ward_seconds` 在正式玩家场景中固定为 `6.0` 秒。
- 不修改 `data/waves/first_run.json` 的怪物数量或 `spawn_interval`。
- 不增加教程文字、按钮、碰撞形状或外部依赖。
- 所有新增行为必须先有失败测试，再写最小实现。

---

### Task 1: 玩家保护状态与伤害门禁

**Files:**
- Modify: `tests/test_player_controller.gd`
- Modify: `scripts/player/player_controller.gd`

**Interfaces:**
- Produces: `is_starting_ward_active() -> bool`
- Produces: `get_starting_ward_ratio() -> float`
- Produces: `tick_starting_ward(delta: float) -> void`
- Preserves: `take_contact_damage(amount: int) -> bool`

- [ ] **Step 1: Write the failing test**

在现有接触伤害断言之前加入：

```gdscript
player.starting_ward_seconds = 6.0
player.start_starting_ward()
runner.assert_true(player.is_starting_ward_active(), "starting ward should activate at run start")
runner.assert_near(player.get_starting_ward_ratio(), 1.0, 0.001, "fresh ward should report full ratio")
runner.assert_true(not player.take_contact_damage(12), "starting ward should reject enemy damage")
runner.assert_eq(health.current_health, 100, "blocked starting damage should preserve health")
player.tick_starting_ward(4.5)
runner.assert_near(player.get_starting_ward_ratio(), 0.25, 0.001, "ward ratio should follow remaining time")
player.tick_starting_ward(1.5)
runner.assert_true(not player.is_starting_ward_active(), "ward should expire after six active seconds")
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
& $godot --headless --path . --script res://tests/run_all_tests.gd
```

Expected: FAIL because `start_starting_ward` and related methods do not exist.

- [ ] **Step 3: Write minimal implementation**

在 `PlayerController` 中加入导出配置、剩余时间和纯状态 API：

```gdscript
@export var starting_ward_seconds: float = 6.0
var starting_ward_remaining: float = 0.0

func start_starting_ward() -> void:
	starting_ward_remaining = maxf(0.0, starting_ward_seconds)

func tick_starting_ward(delta: float) -> void:
	starting_ward_remaining = maxf(0.0, starting_ward_remaining - maxf(0.0, delta))

func is_starting_ward_active() -> bool:
	return starting_ward_remaining > 0.0

func get_starting_ward_ratio() -> float:
	if starting_ward_seconds <= 0.0:
		return 0.0
	return clampf(starting_ward_remaining / starting_ward_seconds, 0.0, 1.0)
```

从 `_ready()` 调用 `start_starting_ward()`，从 `_physics_process(delta)` 调用 `tick_starting_ward(delta)`，并让 `take_contact_damage()` 在保护激活时返回 `false`。

- [ ] **Step 4: Run test to verify it passes**

Run the full Godot test command. Expected: `All tests passed.`

- [ ] **Step 5: Commit**

```powershell
git add scripts/player/player_controller.gd tests/test_player_controller.gd
git commit -m "feat: add starting ward damage gate"
```

### Task 2: 正式阵纹素材与表现组件

**Files:**
- Create: `art/source_green/effects/player/starting_ward_green.png`
- Create: `art/effects/player/starting_ward.png`
- Create: `tests/test_starting_ward_visual.gd`
- Create: `scripts/components/starting_ward_visual.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: parent method `is_starting_ward_active() -> bool`
- Consumes: parent method `get_starting_ward_ratio() -> float`
- Produces: `refresh_visual(delta: float) -> void`

- [ ] **Step 1: Generate and validate the formal asset**

使用 image-2 生成单张俯视护身阵纹：纯 `#00ff00` 背景、青蓝灵光外环、暖金符文、中心透明留空、无文字、无阴影、完整圆环且四周留白。将源图保存在 `art/source_green/effects/player/starting_ward_green.png`，用现有 `tools/chroma_key.py` 提取到 `art/effects/player/starting_ward.png`，验证四角 alpha 为 0 且主体非空。

- [ ] **Step 2: Write the failing visual test**

新建 `tests/test_starting_ward_visual.gd`，使用带 `active` 和 `ratio` 字段的测试宿主、`Sprite2D` 与组件实例，断言：激活时可见且旋转；比例为 0.2 时透明度发生闪烁；失活时隐藏；组件子树不存在 `CollisionShape2D`。

- [ ] **Step 3: Run test to verify it fails**

先把测试路径加入 `TEST_SCRIPTS`，运行完整 Godot 测试。Expected: FAIL because `starting_ward_visual.gd` does not exist.

- [ ] **Step 4: Write minimal visual implementation**

```gdscript
extends Node
class_name StartingWardVisual

@export var sprite_path: NodePath
@export var rotation_speed: float = 0.55
@onready var ward_sprite: Sprite2D = get_node_or_null(sprite_path)
var pulse_time: float = 0.0

func _process(delta: float) -> void:
	refresh_visual(delta)

func refresh_visual(delta: float) -> void:
	var owner_node := get_parent()
	var active := owner_node != null and owner_node.has_method("is_starting_ward_active") and owner_node.is_starting_ward_active()
	if ward_sprite == null:
		ward_sprite = get_node_or_null(sprite_path)
	if ward_sprite == null:
		return
	ward_sprite.visible = active
	if not active:
		return
	pulse_time += maxf(0.0, delta)
	ward_sprite.rotation += rotation_speed * maxf(0.0, delta)
	var ratio := float(owner_node.get_starting_ward_ratio())
	var pulse_speed := 14.0 if ratio <= 0.25 else 4.0
	ward_sprite.modulate.a = 0.72 + sin(pulse_time * pulse_speed) * 0.16
```

- [ ] **Step 5: Run test to verify it passes**

Run the full Godot test command. Expected: `All tests passed.`

- [ ] **Step 6: Commit**

```powershell
git add art/source_green/effects/player/starting_ward_green.png art/effects/player/starting_ward.png scripts/components/starting_ward_visual.gd tests/test_starting_ward_visual.gd tests/run_all_tests.gd
git commit -m "feat: add starting ward visual"
```

### Task 3: 玩家场景接入与完整验收

**Files:**
- Modify: `scenes/player/Player.tscn`
- Modify: `tests/test_game_scene_composition.gd`

**Interfaces:**
- Consumes: `StartingWardVisual.sprite_path`
- Consumes: `res://art/effects/player/starting_ward.png`

- [ ] **Step 1: Write the failing scene test**

在场景组成测试中断言纹理资源存在，玩家场景包含 `StartingWardSprite` 和 `StartingWardVisual`，阵纹 `z_index < AnimatedSprite2D.z_index`，且阵纹分支没有碰撞形状。

- [ ] **Step 2: Run test to verify it fails**

Run the full Godot test command. Expected: FAIL because player scene has no starting ward nodes.

- [ ] **Step 3: Integrate the scene**

在 `Player.tscn` 加入正式纹理和脚下精灵：`z_index = -1`、`scale = Vector2(0.32, 0.32)`、初始 `visible = false`；加入 `StartingWardVisual` 节点并让 `sprite_path` 指向 `../StartingWardSprite`。

- [ ] **Step 4: Import and run automated verification**

```powershell
& $godot --headless --editor --path . --quit
& $godot --headless --path . --script res://tests/run_all_tests.gd
& $godot --headless --path . --script res://tools/simulate_pool_churn.gd
& $godot --headless --path . --quit-after 600
```

Expected: tests print `All tests passed.`, pool churn reports no active leaks, smoke exits with code 0 and no parser/runtime error.

- [ ] **Step 5: Perform mobile visual smoke test**

以 `390x844` 窗口启动游戏，观察至少 8 秒：前 6 秒阵纹可见并随角色移动、怪物与飞剑正常运行、生命不下降；阵纹消失后接触伤害和现有受击反馈恢复。确认 HUD、暂停按钮、摇杆和升级面板无重叠。

- [ ] **Step 6: Commit and push**

```powershell
git add scenes/player/Player.tscn tests/test_game_scene_composition.gd
git commit -m "feat: integrate starting ward"
git push origin main
```
