# Action State Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace player sliding with a production three-direction walk cycle and make enemy contact and charge damage obey explicit windup, active, and recovery states.

**Architecture:** A reusable Python pipeline converts generated 3x2 contact sheets into six-frame strips with a fixed foot anchor. A focused `DirectionalAnimation` presentation component owns player direction and frame selection. A pure `EnemyActionState` owns combat timing while `EnemyAgent` translates those states into movement, damage, and visual telegraphs.

**Tech Stack:** Godot 4.7, GDScript, Python 3, Pillow 12.2, built-in image-2, Git.

## Global Constraints

- Final player walk frames are `128 x 128`, use a fixed foot anchor at y=112, and play at 10 FPS.
- Player movement supports front, back, and right-facing side strips; left uses the side strip with horizontal mirroring.
- Generated source sheets use flat `#00ff00`; transparent strips and green source sheets are both committed.
- No generated sequence is accepted if identity, clothing structure, body proportions, camera position, or frame order visibly drifts.
- Enemy damage is possible only during the active state; windup and recovery never deal damage.
- Charge enemies use locomotion speed before their telegraph, then charge speed only during the active state.
- Scene presentation remains separate from action timing rules.
- No API key, access key, token, or credential is written to the repository.
- Every production-code change follows red-green-refactor and ends with the full Godot suite.

---

## File Map

- Create `tools/sprite_pipeline.py`: split 3x2 transparent contact sheets, normalize foot anchors, and pack horizontal strips.
- Create `tests/tools/test_sprite_pipeline.py`: verify frame count, strip size, alpha, and foot alignment.
- Create `scripts/components/directional_animation.gd`: build `SpriteFrames` from strips and select animations from movement vectors.
- Create `tests/test_directional_animation.gd`: verify animations, direction resolution, and side mirroring.
- Modify `tests/run_all_tests.gd`: register new Godot tests.
- Generate three player walk contact sheets and three final transparent strips.
- Modify `scenes/player/Player.tscn`: use `AnimatedSprite2D` plus `DirectionalAnimation`.
- Modify `scripts/player/player_controller.gd`: forward movement vectors to the presentation component.
- Modify `tests/test_game_scene_composition.gd`: require the animation nodes and production strips.
- Create `scripts/systems/enemy_action_state.gd`: deterministic locomotion/windup/active/recovery/dead timing.
- Create `tests/test_enemy_action_state.gd`: verify state transitions and damage window semantics.
- Modify `scripts/enemies/enemy_agent.gd`: gate movement and damage through `EnemyActionState`.
- Modify `tests/test_enemy_agent.gd`: verify contact windup and charging telegraph behavior.
- Modify enemy JSON definitions: declare attack timing values.

---

### Task 1: Sprite Contact-Sheet Pipeline

**Files:**
- Create: `tools/sprite_pipeline.py`
- Create: `tests/tools/test_sprite_pipeline.py`

**Interfaces:**
- Consumes: transparent RGBA contact sheet arranged left-to-right in a 3-column, 2-row grid.
- Produces: `process_sheet(input_path: Path, output_path: Path, columns: int, rows: int, target_size: int, foot_y: int, padding: int) -> dict` and a `6 * 128` by `128` horizontal PNG strip.

- [ ] **Step 1: Write the failing pipeline test**

Create `tests/tools/test_sprite_pipeline.py`:

```python
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.sprite_pipeline import process_sheet


class SpritePipelineTests(unittest.TestCase):
    def test_splits_six_frames_and_aligns_feet(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "contact_sheet.png"
            output = Path(directory) / "walk_strip.png"
            image = Image.new("RGBA", (300, 200), (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            for index in range(6):
                column = index % 3
                row = index // 3
                left = column * 100 + 30 + index % 2
                top = row * 100 + 15 + index % 3
                draw.rectangle((left, top, left + 39, top + 69), fill=(80 + index * 20, 40, 180, 255))
            image.save(source)

            report = process_sheet(source, output, columns=3, rows=2, target_size=128, foot_y=112, padding=8)

            strip = Image.open(output).convert("RGBA")
            self.assertEqual(strip.size, (768, 128))
            self.assertEqual(report["frame_count"], 6)
            self.assertEqual(report["foot_y"], 112)
            for index in range(6):
                frame = strip.crop((index * 128, 0, (index + 1) * 128, 128))
                bounds = frame.getchannel("A").getbbox()
                self.assertIsNotNone(bounds)
                self.assertEqual(bounds[3], 112)
                self.assertLessEqual(abs((bounds[2] - bounds[0]) - report["widths"][0]), 4)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test and verify the missing module failure**

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_sprite_pipeline.py -v
```

Expected: FAIL because `tools.sprite_pipeline` does not exist.

- [ ] **Step 3: Implement the contact-sheet pipeline**

Create `tools/sprite_pipeline.py`:

```python
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _normalize_frame(frame: Image.Image, target_size: int, foot_y: int, padding: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    rgba = frame.convert("RGBA")
    bounds = rgba.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Contact sheet contains an empty frame")
    subject = rgba.crop(bounds)
    available_width = target_size - padding * 2
    available_height = foot_y - padding
    scale = min(available_width / subject.width, available_height / subject.height)
    width = max(1, round(subject.width * scale))
    height = max(1, round(subject.height * scale))
    subject = subject.resize((width, height), Image.Resampling.NEAREST)
    output = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    x = (target_size - width) // 2
    y = foot_y - height
    output.alpha_composite(subject, (x, y))
    normalized_bounds = output.getchannel("A").getbbox()
    if normalized_bounds is None:
        raise ValueError("Normalized frame contains no visible pixels")
    return output, normalized_bounds


def process_sheet(
    input_path: Path,
    output_path: Path,
    columns: int = 3,
    rows: int = 2,
    target_size: int = 128,
    foot_y: int = 112,
    padding: int = 8,
) -> dict:
    if columns <= 0 or rows <= 0:
        raise ValueError("columns and rows must be positive")
    if target_size <= 0 or foot_y <= padding or foot_y > target_size:
        raise ValueError("target size, foot position, and padding are inconsistent")
    sheet = Image.open(input_path).convert("RGBA")
    if sheet.width % columns != 0 or sheet.height % rows != 0:
        raise ValueError("contact sheet dimensions must divide evenly by the grid")
    cell_width = sheet.width // columns
    cell_height = sheet.height // rows
    frames: list[Image.Image] = []
    widths: list[int] = []
    heights: list[int] = []
    for row in range(rows):
        for column in range(columns):
            cell = sheet.crop((
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            ))
            frame, bounds = _normalize_frame(cell, target_size, foot_y, padding)
            frames.append(frame)
            widths.append(bounds[2] - bounds[0])
            heights.append(bounds[3] - bounds[1])
    strip = Image.new("RGBA", (target_size * len(frames), target_size), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        strip.alpha_composite(frame, (index * target_size, 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(output_path)
    return {
        "frame_count": len(frames),
        "frame_size": target_size,
        "foot_y": foot_y,
        "widths": widths,
        "heights": heights,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Split and normalize an animation contact sheet.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--rows", type=int, default=2)
    parser.add_argument("--target-size", type=int, default=128)
    parser.add_argument("--foot-y", type=int, default=112)
    parser.add_argument("--padding", type=int, default=8)
    arguments = parser.parse_args()
    report = process_sheet(
        arguments.input,
        arguments.output,
        columns=arguments.columns,
        rows=arguments.rows,
        target_size=arguments.target_size,
        foot_y=arguments.foot_y,
        padding=arguments.padding,
    )
    print(report)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the focused Python tests**

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_sprite_pipeline.py -v
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_chroma_key.py -v
```

Expected: both tests report `OK`.

- [ ] **Step 5: Commit the sprite pipeline**

```powershell
git add tools/sprite_pipeline.py tests/tools/test_sprite_pipeline.py
git commit -m "feat: add anchored sprite sheet pipeline"
```

---

### Task 2: Directional Animation Presentation Component

**Files:**
- Create: `scripts/components/directional_animation.gd`
- Create: `tests/test_directional_animation.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: one `AnimatedSprite2D` and front/back/side horizontal strips containing six `128 x 128` frames.
- Produces: `configure(...) -> bool`, `update_motion(motion: Vector2) -> StringName`, and stable animation names `idle_front`, `idle_back`, `idle_side`, `walk_front`, `walk_back`, `walk_side`.

- [ ] **Step 1: Write the failing direction-controller test**

Create `tests/test_directional_animation.gd`:

```gdscript
extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/components/directional_animation.gd"):
		runner.assert_true(false, "directional animation component should exist")
		return
	var controller_script = load("res://scripts/components/directional_animation.gd")
	var controller = controller_script.new()
	var sprite := AnimatedSprite2D.new()
	var image := Image.create(768, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var strip := ImageTexture.create_from_image(image)

	runner.assert_true(controller.configure(sprite, strip, strip, strip), "directional animation should configure valid strips")
	runner.assert_true(sprite.sprite_frames.has_animation("walk_front"), "front walk animation should exist")
	runner.assert_eq(sprite.sprite_frames.get_frame_count("walk_front"), 6, "front walk should contain six frames")
	runner.assert_eq(controller.update_motion(Vector2.RIGHT), &"walk_side", "right movement should use side walk")
	runner.assert_true(not sprite.flip_h, "right movement should not mirror the side strip")
	runner.assert_eq(controller.update_motion(Vector2.LEFT), &"walk_side", "left movement should use side walk")
	runner.assert_true(sprite.flip_h, "left movement should mirror the side strip")
	runner.assert_eq(controller.update_motion(Vector2.UP), &"walk_back", "up movement should use back walk")
	runner.assert_eq(controller.update_motion(Vector2.ZERO), &"idle_back", "stopping should retain the last direction")
	runner.assert_eq(controller.update_motion(Vector2.DOWN), &"walk_front", "down movement should use front walk")

	controller.free()
	sprite.free()
```

Register it after `test_player_controller.gd` in `tests/run_all_tests.gd`:

```gdscript
	"res://tests/test_directional_animation.gd",
```

- [ ] **Step 2: Run the Godot suite and verify the missing-component failure**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because the component script does not exist.

- [ ] **Step 3: Implement DirectionalAnimation**

Create `scripts/components/directional_animation.gd`:

```gdscript
extends Node
class_name DirectionalAnimation

@export var sprite_path: NodePath = NodePath("../AnimatedSprite2D")
@export var front_strip: Texture2D
@export var back_strip: Texture2D
@export var side_strip: Texture2D
@export var frame_size := Vector2i(128, 128)
@export var frame_count: int = 6
@export var animation_fps: float = 10.0

var sprite: AnimatedSprite2D
var last_direction: String = "front"

func _ready() -> void:
	if sprite == null:
		sprite = get_node_or_null(sprite_path) as AnimatedSprite2D
	configure(sprite, front_strip, back_strip, side_strip)

func configure(target_sprite: AnimatedSprite2D, front: Texture2D, back: Texture2D, side: Texture2D) -> bool:
	if target_sprite == null or front == null or back == null or side == null:
		return false
	sprite = target_sprite
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_direction(frames, "front", front)
	_add_direction(frames, "back", back)
	_add_direction(frames, "side", side)
	sprite.sprite_frames = frames
	sprite.play(&"idle_front")
	return true

func update_motion(motion: Vector2) -> StringName:
	if sprite == null:
		return StringName()
	var moving := motion.length() > 0.05
	if moving:
		last_direction = _resolve_direction(motion)
	sprite.flip_h = last_direction == "side" and motion.x < -0.05
	var prefix := "walk" if moving else "idle"
	var animation := StringName("%s_%s" % [prefix, last_direction])
	if sprite.animation != animation or not sprite.is_playing():
		sprite.play(animation)
	return animation

func _resolve_direction(motion: Vector2) -> String:
	if absf(motion.x) > absf(motion.y):
		return "side"
	return "back" if motion.y < 0.0 else "front"

func _add_direction(frames: SpriteFrames, direction: String, texture: Texture2D) -> void:
	var idle_name := StringName("idle_%s" % direction)
	var walk_name := StringName("walk_%s" % direction)
	frames.add_animation(idle_name)
	frames.set_animation_loop(idle_name, true)
	frames.set_animation_speed(idle_name, 4.0)
	frames.add_frame(idle_name, _atlas_frame(texture, 0))
	frames.add_animation(walk_name)
	frames.set_animation_loop(walk_name, true)
	frames.set_animation_speed(walk_name, animation_fps)
	for index in range(frame_count):
		frames.add_frame(walk_name, _atlas_frame(texture, index))

func _atlas_frame(texture: Texture2D, index: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = Rect2(index * frame_size.x, 0, frame_size.x, frame_size.y)
	return frame
```

- [ ] **Step 4: Run the full Godot suite**

Run the command from Step 2.

Expected: `All tests passed.`

- [ ] **Step 5: Commit the presentation component**

```powershell
git add scripts/components/directional_animation.gd tests/test_directional_animation.gd tests/run_all_tests.gd
git commit -m "feat: add directional animation component"
```

---

### Task 3: Generate and Integrate Player Walk Animation

**Files:**
- Create: `art/source_green/player_walk_front_6_green.png`
- Create: `art/source_green/player_walk_back_6_green.png`
- Create: `art/source_green/player_walk_side_6_green.png`
- Create: `art/characters/player/animation/walk_front_strip.png`
- Create: `art/characters/player/animation/walk_back_strip.png`
- Create: `art/characters/player/animation/walk_side_strip.png`
- Modify: `scenes/player/Player.tscn`
- Modify: `scripts/player/player_controller.gd`
- Modify: `tests/test_game_scene_composition.gd`

**Interfaces:**
- Consumes: approved current player key poses and three generated 3x2 contact sheets.
- Produces: six-frame front/back/side strips, an `AnimatedSprite2D`, and movement-vector forwarding to `DirectionalAnimation`.

- [ ] **Step 1: Add failing scene-composition assertions**

In `tests/test_game_scene_composition.gd`, add assertions for the instantiated player:

```gdscript
	var player = game.get_node_or_null("Player")
	runner.assert_true(player != null, "game should include the player")
	if player != null:
		runner.assert_true(player.get_node_or_null("AnimatedSprite2D") is AnimatedSprite2D, "player should use AnimatedSprite2D")
		runner.assert_true(player.get_node_or_null("DirectionalAnimation") != null, "player should include directional animation control")
	for strip_path in [
		"res://art/characters/player/animation/walk_front_strip.png",
		"res://art/characters/player/animation/walk_back_strip.png",
		"res://art/characters/player/animation/walk_side_strip.png",
	]:
		runner.assert_true(ResourceLoader.exists(strip_path), "%s should exist" % strip_path)
```

- [ ] **Step 2: Run the Godot suite and verify scene and asset failures**

Run the standard Godot test command.

Expected: FAIL because the player still uses `Sprite2D` and the three strips do not exist.

- [ ] **Step 3: Generate three production contact sheets with built-in image-2**

Use the current `player_front.png`, `player_back.png`, `player_right.png`, and `player_artificer_sheet.png` as identity/style references. Generate one image per direction with the following normalized prompt, changing only the direction phrase:

```text
Use case: stylized-concept
Asset type: production mobile 2D game walk-cycle contact sheet
Primary request: the exact same artificer cultivator character from the reference images performing one seamless six-frame walk cycle [toward the viewer / away from the viewer / toward screen right]
Style/medium: crisp 3/4 top-down eastern fantasy pixel art matching the references exactly
Composition/framing: a strict 3-column by 2-row grid; frames 1-3 in the top row and 4-6 in the bottom row; one complete character centered in each equal cell; identical camera, scale, body proportions, outfit, hairstyle, backpack, palette, and lighting in every frame; no grid lines
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background in every cell
Motion: natural alternating footfalls and restrained robe/backpack secondary motion; frame 6 transitions naturally back to frame 1
Constraints: exactly six frames, no labels, no text, no shadows, no floor, no camera movement, no crop, no duplicated pose, no extra objects, no weapon, no watermark, do not use #00ff00 in the character
Avoid: identity drift, clothing redesign, changing facial features, changing proportions, changing equipment placement, perspective changes, painterly blur
```

Save the generated outputs at the exact green-source paths above.

- [ ] **Step 4: Remove green and pack the strips**

Run the installed imagegen helper for each exact source/output pair:

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\Nothin\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py' --input art/source_green/player_walk_front_6_green.png --out tmp/imagegen/player_walk_front_raw.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --edge-contract 1 --force
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\Nothin\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py' --input art/source_green/player_walk_back_6_green.png --out tmp/imagegen/player_walk_back_raw.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --edge-contract 1 --force
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'C:\Users\Nothin\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py' --input art/source_green/player_walk_side_6_green.png --out tmp/imagegen/player_walk_side_raw.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --edge-contract 1 --force
```

Then run:

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/sprite_pipeline.py tmp/imagegen/player_walk_front_raw.png art/characters/player/animation/walk_front_strip.png --columns 3 --rows 2 --target-size 128 --foot-y 112 --padding 8
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/sprite_pipeline.py tmp/imagegen/player_walk_back_raw.png art/characters/player/animation/walk_back_strip.png --columns 3 --rows 2 --target-size 128 --foot-y 112 --padding 8
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/sprite_pipeline.py tmp/imagegen/player_walk_side_raw.png art/characters/player/animation/walk_side_strip.png --columns 3 --rows 2 --target-size 128 --foot-y 112 --padding 8
```

Expected: three `768 x 128` transparent strips and reports containing six frames with foot y=112.

- [ ] **Step 5: Inspect all strips before integration**

Reject and regenerate a direction if any of these conditions occur:

- fewer or more than six isolated figures;
- character identity, outfit, hair, backpack, scale, or viewpoint changes between cells;
- frame order cannot make a loop;
- green fringe or nontransparent background remains;
- a frame is cropped or contains an extra object.

If two image-2 attempts for one direction fail these checks, stop this task before integration and report the exact failed checks. The approved 5-second fixed-camera image-to-video fallback is then handled as its own reviewed asset-production task; video is never used directly in Godot.

- [ ] **Step 6: Replace the player scene sprite**

Update `scenes/player/Player.tscn` to use:

```text
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/components/directional_animation.gd" id="3"]
[ext_resource type="Texture2D" path="res://art/characters/player/animation/walk_front_strip.png" id="4"]
[ext_resource type="Texture2D" path="res://art/characters/player/animation/walk_back_strip.png" id="5"]
[ext_resource type="Texture2D" path="res://art/characters/player/animation/walk_side_strip.png" id="6"]

[sub_resource type="CircleShape2D" id="CircleShape2D_player"]
radius = 18.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
texture_filter = 1
position = Vector2(0, -12)
scale = Vector2(0.72, 0.72)

[node name="DirectionalAnimation" type="Node" parent="."]
script = ExtResource("3")
sprite_path = NodePath("../AnimatedSprite2D")
front_strip = ExtResource("4")
back_strip = ExtResource("5")
side_strip = ExtResource("6")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_player")

[node name="Camera2D" type="Camera2D" parent="."]
enabled = true
```

- [ ] **Step 7: Forward movement to the animation component**

Add to `scripts/player/player_controller.gd`:

```gdscript
@onready var animation_controller: Node = get_node_or_null("DirectionalAnimation")
```

In `_physics_process`, after clamping `input_vector`, add:

```gdscript
	if animation_controller != null and animation_controller.has_method("update_motion"):
		animation_controller.update_motion(input_vector)
```

- [ ] **Step 8: Import assets and run the full Godot suite**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --editor --path . --import
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: import exits 0 and tests print `All tests passed.`

- [ ] **Step 9: Commit player movement animation**

```powershell
git add art/source_green/player_walk_*_green.png art/characters/player/animation scenes/player/Player.tscn scripts/player/player_controller.gd tests/test_game_scene_composition.gd
git commit -m "feat: animate player directional movement"
```

---

### Task 4: Deterministic Enemy Action State

**Files:**
- Create: `scripts/systems/enemy_action_state.gd`
- Create: `tests/test_enemy_action_state.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: states `locomotion`, `windup`, `active`, `recovery`, `dead`; `start_attack(windup, active, recovery) -> bool`; `tick(delta) -> Array[String]`; `is_damage_active() -> bool`.

- [ ] **Step 1: Write the failing state-transition test**

Create `tests/test_enemy_action_state.gd`:

```gdscript
extends RefCounted

func run(runner) -> void:
	if not ResourceLoader.exists("res://scripts/systems/enemy_action_state.gd"):
		runner.assert_true(false, "enemy action state should exist")
		return
	var state_script = load("res://scripts/systems/enemy_action_state.gd")
	var state = state_script.new()
	runner.assert_eq(state.state, "locomotion", "enemy action should begin in locomotion")
	runner.assert_true(state.start_attack(0.3, 0.1, 0.4), "locomotion should start an attack")
	runner.assert_eq(state.state, "windup", "attack should begin with windup")
	runner.assert_true(not state.is_damage_active(), "windup should not deal damage")
	runner.assert_eq(state.tick(0.2).size(), 0, "partial windup should not transition")
	var active_transitions = state.tick(0.1)
	runner.assert_true(active_transitions.has("active"), "completed windup should enter active")
	runner.assert_true(state.is_damage_active(), "active state should enable damage")
	var recovery_transitions = state.tick(0.1)
	runner.assert_true(recovery_transitions.has("recovery"), "completed active window should enter recovery")
	runner.assert_true(not state.is_damage_active(), "recovery should disable damage")
	var locomotion_transitions = state.tick(0.4)
	runner.assert_true(locomotion_transitions.has("locomotion"), "completed recovery should resume locomotion")
	state.mark_dead()
	runner.assert_eq(state.state, "dead", "death should override the action state")
	runner.assert_true(not state.start_attack(0.1, 0.1, 0.1), "dead enemies cannot start attacks")
```

Register it after `test_enemy_agent.gd` in `tests/run_all_tests.gd`.

- [ ] **Step 2: Run the Godot suite and verify the missing-state failure**

Run the standard Godot test command.

Expected: FAIL because `enemy_action_state.gd` does not exist.

- [ ] **Step 3: Implement EnemyActionState**

Create `scripts/systems/enemy_action_state.gd`:

```gdscript
extends RefCounted
class_name EnemyActionState

const LOCOMOTION := "locomotion"
const WINDUP := "windup"
const ACTIVE := "active"
const RECOVERY := "recovery"
const DEAD := "dead"

var state: String = LOCOMOTION
var remaining: float = 0.0
var active_duration: float = 0.1
var recovery_duration: float = 0.4

func reset() -> void:
	state = LOCOMOTION
	remaining = 0.0

func start_attack(windup: float, active: float, recovery: float) -> bool:
	if state != LOCOMOTION:
		return false
	state = WINDUP
	remaining = maxf(0.001, windup)
	active_duration = maxf(0.001, active)
	recovery_duration = maxf(0.001, recovery)
	return true

func tick(delta: float) -> Array[String]:
	var transitions: Array[String] = []
	if state == LOCOMOTION or state == DEAD:
		return transitions
	remaining -= maxf(0.0, delta)
	while remaining <= 0.0 and state != LOCOMOTION and state != DEAD:
		var overflow := -remaining
		match state:
			WINDUP:
				state = ACTIVE
				remaining = active_duration - overflow
			ACTIVE:
				state = RECOVERY
				remaining = recovery_duration - overflow
			RECOVERY:
				state = LOCOMOTION
				remaining = 0.0
		transitions.append(state)
	return transitions

func is_damage_active() -> bool:
	return state == ACTIVE

func can_move() -> bool:
	return state == LOCOMOTION

func mark_dead() -> void:
	state = DEAD
	remaining = 0.0
```

- [ ] **Step 4: Run the full Godot suite**

Expected: `All tests passed.`

- [ ] **Step 5: Commit the action state**

```powershell
git add scripts/systems/enemy_action_state.gd tests/test_enemy_action_state.gd tests/run_all_tests.gd
git commit -m "feat: add deterministic enemy action state"
```

---

### Task 5: Gate Enemy Damage and Charging Through Action States

**Files:**
- Modify: `scripts/enemies/enemy_agent.gd`
- Modify: `tests/test_enemy_agent.gd`
- Modify: `data/enemies/basic_demon.json`
- Modify: `data/enemies/charging_demon.json`
- Modify: `data/enemies/ranged_demon.json`

**Interfaces:**
- Consumes: timing keys `attack_windup`, `attack_active`, `attack_recovery`, and `charge_trigger_range`.
- Produces: `calculate_action_velocity(delta: float) -> Vector2`, visible windup/active/recovery tinting, one gated contact hit per action, and charge-speed movement only in the active state.

- [ ] **Step 1: Add failing contact and charge timing tests**

In `tests/test_enemy_agent.gd`, change the direct charge velocity assertion to expect locomotion speed:

```gdscript
		runner.assert_near(charge_velocity.length(), 95.0, 0.01, "charging enemy should approach at locomotion speed before windup")
```

Before the existing direct `try_apply_contact_damage` block, add:

```gdscript
	var timed_target := ContactTarget.new()
	timed_target.global_position = Vector2(18, 0)
	enemy.global_position = Vector2.ZERO
	enemy.configure({
		"behavior": "chase",
		"contact_damage": 11,
		"collision_radius": 18.0,
		"max_health": 24,
		"attack_windup": 0.28,
		"attack_active": 0.10,
		"attack_recovery": 0.48,
	}, timed_target)
	var windup_velocity = enemy.calculate_action_velocity(0.0)
	runner.assert_eq(windup_velocity, Vector2.ZERO, "contact attack should stop during windup")
	runner.assert_eq(enemy.action_state.state, "windup", "contact range should begin windup")
	runner.assert_eq(timed_target.damage_amounts.size(), 0, "windup should not deal contact damage")
	enemy.calculate_action_velocity(0.28)
	runner.assert_eq(enemy.action_state.state, "active", "completed contact windup should enter active")
	runner.assert_eq(timed_target.damage_amounts.size(), 1, "active contact frame should deal one hit")
	timed_target.free()

	var charge_target := ContactTarget.new()
	charge_target.global_position = Vector2(200, 0)
	enemy.global_position = Vector2.ZERO
	enemy.configure({
		"behavior": "charge",
		"move_speed": 95,
		"charge_speed": 260,
		"charge_trigger_range": 360,
		"attack_windup": 0.55,
		"attack_active": 0.45,
		"attack_recovery": 0.65,
		"max_health": 38,
	}, charge_target)
	runner.assert_eq(enemy.calculate_action_velocity(0.0), Vector2.ZERO, "charge trigger should begin a stationary windup")
	runner.assert_eq(enemy.action_state.state, "windup", "charge should visibly wind up")
	var active_charge_velocity = enemy.calculate_action_velocity(0.55)
	runner.assert_near(active_charge_velocity.length(), 260.0, 0.01, "active charge should use charge speed")
	runner.assert_eq(enemy.action_state.state, "active", "charge should enter active after windup")
	charge_target.free()
```

- [ ] **Step 2: Run the suite and verify timing failures**

Expected: FAIL because `calculate_action_velocity`, `action_state`, and gated timing do not exist, and charge approach still uses charge speed.

- [ ] **Step 3: Integrate EnemyActionState in EnemyAgent**

In `scripts/enemies/enemy_agent.gd`, add the state preload after `GameConstantsScript`:

```gdscript
const EnemyActionStateScript = preload("res://scripts/systems/enemy_action_state.gd")
```

Add these exported tuning fields after `preferred_range`:

```gdscript
@export var charge_trigger_range: float = 340.0
@export var attack_windup: float = 0.28
@export var attack_active: float = 0.10
@export var attack_recovery: float = 0.48
```

Add these runtime fields after `behavior`:

```gdscript
var action_state = EnemyActionStateScript.new()
var locked_action_direction: Vector2 = Vector2.RIGHT
var damage_applied_this_action: bool = false
```

In `configure`, immediately after setting `behavior`, reset the action state and load exact timing values:

```gdscript
	action_state.reset()
	locked_action_direction = Vector2.RIGHT
	damage_applied_this_action = false
	charge_trigger_range = float(definition.get("charge_trigger_range", charge_trigger_range))
	attack_windup = float(definition.get("attack_windup", attack_windup))
	attack_active = float(definition.get("attack_active", attack_active))
	attack_recovery = float(definition.get("attack_recovery", attack_recovery))
```

Replace `_physics_process` with:

```gdscript
func _physics_process(delta: float) -> void:
	velocity = calculate_action_velocity(delta)
	move_and_slide()
```

Add `calculate_action_velocity`, `_calculate_charge_velocity`, `_is_target_in_contact_range`, `_try_action_damage`, and `_update_action_visual` with this exact state behavior:

```gdscript
func calculate_action_velocity(delta: float) -> Vector2:
	var transitions := action_state.tick(delta)
	if transitions.has(EnemyActionStateScript.ACTIVE):
		damage_applied_this_action = false
	var result := Vector2.ZERO
	if action_state.state == EnemyActionStateScript.ACTIVE:
		_try_action_damage()
		if behavior == "charge":
			result = locked_action_direction * charge_speed
	elif action_state.state == EnemyActionStateScript.LOCOMOTION:
		if behavior == "charge":
			result = _calculate_charge_velocity()
		else:
			result = calculate_desired_velocity(delta)
			if _is_target_in_contact_range():
				locked_action_direction = global_position.direction_to(target.global_position)
				action_state.start_attack(attack_windup, attack_active, attack_recovery)
				result = Vector2.ZERO
	_update_action_visual()
	return result

func _calculate_charge_velocity() -> Vector2:
	if target == null:
		return Vector2.ZERO
	var to_target := target.global_position - global_position
	if to_target == Vector2.ZERO:
		return Vector2.ZERO
	if to_target.length() <= charge_trigger_range:
		locked_action_direction = to_target.normalized()
		damage_applied_this_action = false
		action_state.start_attack(attack_windup, attack_active, attack_recovery)
		return Vector2.ZERO
	return to_target.normalized() * move_speed

func _is_target_in_contact_range() -> bool:
	if target == null:
		return false
	var contact_range := get_contact_radius() + _get_target_contact_radius(target)
	return global_position.distance_to(target.global_position) <= contact_range

func _try_action_damage() -> void:
	if damage_applied_this_action:
		return
	if try_apply_contact_damage():
		damage_applied_this_action = true

func _update_action_visual() -> void:
	if sprite == null:
		return
	match action_state.state:
		EnemyActionStateScript.WINDUP:
			sprite.modulate = Color(1.0, 0.65, 0.25)
		EnemyActionStateScript.ACTIVE:
			sprite.modulate = Color(1.0, 0.3, 0.3)
		EnemyActionStateScript.RECOVERY:
			sprite.modulate = Color(0.72, 0.72, 0.72)
		_:
			sprite.modulate = Color.WHITE
```

Change the `charge` branch of `calculate_desired_velocity` to:

```gdscript
		"charge":
			return to_target.normalized() * move_speed
```

Replace `_on_died` with:

```gdscript
func _on_died() -> void:
	action_state.mark_dead()
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	defeated.emit(get_defeat_payload())
	queue_free()
```

- [ ] **Step 4: Add timing data**

Add to `basic_demon.json`:

```json
  "attack_windup": 0.28,
  "attack_active": 0.10,
  "attack_recovery": 0.48,
```

Add to `charging_demon.json`:

```json
  "charge_trigger_range": 360,
  "attack_windup": 0.55,
  "attack_active": 0.45,
  "attack_recovery": 0.65,
```

Add to `ranged_demon.json`:

```json
  "attack_windup": 0.30,
  "attack_active": 0.10,
  "attack_recovery": 0.50,
```

- [ ] **Step 5: Run the full Godot suite**

Expected: `All tests passed.`

- [ ] **Step 6: Commit enemy action timing**

```powershell
git add scripts/enemies/enemy_agent.gd tests/test_enemy_agent.gd data/enemies/basic_demon.json data/enemies/charging_demon.json data/enemies/ranged_demon.json
git commit -m "feat: gate enemy attacks through action states"
```

---

### Task 6: Full Verification, Visual Run, and Publication

**Files:**
- Verify all files changed by Tasks 1-5.

- [ ] **Step 1: Run both Python tool tests**

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_chroma_key.py -v
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_sprite_pipeline.py -v
```

- [ ] **Step 2: Import assets and run all Godot tests**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --editor --path . --import
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

- [ ] **Step 3: Run a 300-frame headless scene smoke test**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit-after 300
```

- [ ] **Step 4: Inspect repository state**

```powershell
git diff --check
git status --short --branch
git log -8 --oneline --decorate
```

Expected: clean `main`, only the planned commits ahead of `origin/main`.

- [ ] **Step 5: Launch and visually verify the game**

Run the game visibly and verify:

- player changes front/back/side animation with movement;
- side animation mirrors only when moving left;
- feet remain visually anchored without frame-to-frame jumping;
- basic enemies pause and turn orange before contact damage;
- charging enemies pause and telegraph before moving at charge speed;
- active damage tint is visibly red and recovery tint is gray;
- no animation or warning obscures the existing upgrade interface.

- [ ] **Step 6: Push `main`**

```powershell
git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c http.version=HTTP/1.1 -c core.compression=9 push --progress origin main
```

---

## Plan Self-Review

- Scope coverage: implements sub-project 2 from the approved master design: player/enemy animation contract, enemy damage windows, charge telegraph, and the first production movement animation.
- Scope boundary: hurt, active-skill, and death animation sequences; ranged projectiles; other playable characters; and additional enemy animation sheets remain in later independently tested increments.
- Type consistency: presentation uses `AnimatedSprite2D`; timing uses the pure `EnemyActionState`; `EnemyAgent` never enables damage from presentation state alone.
- Asset consistency: generated contact sheets are 3x2, processed strips are 6x1, and both tools agree on six `128 x 128` frames with foot y=112.
- Verification consistency: Python tooling, Godot state logic, scene composition, asset imports, headless runtime, and visible behavior each have a dedicated check.
