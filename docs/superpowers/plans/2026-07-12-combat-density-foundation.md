# Combat Density Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the first three minutes continuously busy and varied, expand the runtime upgrade pool from 12 to 20 choices, add the radial Spirit Needle Array as the fifth weapon, and give projectile weapons distinct production visuals.

**Architecture:** Keep the current data-driven boundaries. Wave density remains in `data/waves`, upgrade composition remains in `UpgradeSystem`, weapon definitions produce normalized fire events through `WeaponSystem`, and `GameLoop` only translates those events into projectiles. A small Pillow tool converts image-2 green-screen sources into normalized transparent PNG assets.

**Tech Stack:** Godot 4.7, GDScript, JSON content definitions, Python 3 with Pillow 12.2, built-in image-2, Git.

## Global Constraints

- Android remains the first target; gameplay must stay readable in portrait orientation.
- Scenes own presentation, systems own rules, and data owns content.
- Ordinary enemies remain below the 120-140 recommended active cap; denser wave requests must remain interval-spawned.
- High-threat enemy actions and warnings may not be skipped to preserve frame rate.
- Generated cutout sources use flat `#00ff00` green and final transparent assets are committed under `art`.
- No API key, access key, token, or generated credential may be written to the repository.
- Every production-code change follows red-green-refactor and ends with focused plus full verification.

---

## File Map

- Create `tools/chroma_key.py`: reusable green-screen removal and fixed-canvas normalization CLI.
- Create `tests/tools/test_chroma_key.py`: Pillow unit coverage for transparency and normalization.
- Modify `tests/test_game_database.gd`: first-three-minute density, variety, and content-count contracts.
- Modify `data/waves/first_run.json`: interval-spawned mixed waves through minute three.
- Modify `tests/test_upgrade_system.gd`: stat-bundle aggregation and summary coverage.
- Modify `scripts/systems/upgrade_system.gd`: support `stat_bundle` upgrades.
- Modify `data/upgrades/core_upgrades.json`: six stat bundles plus Spirit Needle unlock and level entries.
- Modify `tests/test_combat_resolver.gd`: radial direction geometry coverage.
- Modify `scripts/systems/combat_resolver.gd`: build evenly spaced radial projectile directions.
- Modify `tests/test_weapon_system.gd`: Spirit Needle event and level growth coverage.
- Modify `scripts/systems/weapon_system.gd`: include aim and visual metadata in fire events.
- Modify `scripts/core/game_loop.gd`: spawn radial events without nearest-target aiming.
- Create `data/weapons/spirit_needle_array.json`: fifth weapon definition.
- Modify `tests/test_projectile.gd`: event-driven texture, scale, and tint coverage.
- Modify `scripts/weapons/projectile.gd`: apply event visual metadata.
- Modify existing projectile weapon JSON files: connect production projectile textures.
- Create green source and transparent final PNG assets for Spirit Needle, Talisman Fire, and Mechanism Crossbow projectiles plus the Spirit Needle icon.

---

### Task 1: Reusable Green-Screen Asset Tool

**Files:**
- Create: `tools/chroma_key.py`
- Create: `tests/tools/test_chroma_key.py`

**Interfaces:**
- Consumes: RGBA or RGB PNG plus key color, inner/outer tolerance, and optional square canvas size.
- Produces: `process_image(input_path: Path, output_path: Path, inner: float, outer: float, canvas_size: int, padding: int) -> None` and a CLI with positional input/output paths.

- [ ] **Step 1: Write the failing Pillow unit test**

Create `tests/tools/test_chroma_key.py`:

```python
from pathlib import Path
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from tools.chroma_key import process_image


class ChromaKeyTests(unittest.TestCase):
    def test_removes_green_preserves_subject_and_normalizes_canvas(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.png"
            output = Path(directory) / "output.png"
            image = Image.new("RGBA", (6, 4), (0, 255, 0, 255))
            image.putpixel((2, 1), (220, 40, 80, 255))
            image.putpixel((3, 1), (220, 40, 80, 255))
            image.putpixel((2, 2), (220, 40, 80, 255))
            image.putpixel((3, 2), (220, 40, 80, 255))
            image.save(source)

            process_image(source, output, inner=12.0, outer=72.0, canvas_size=32, padding=4)

            result = Image.open(output).convert("RGBA")
            self.assertEqual(result.size, (32, 32))
            self.assertEqual(result.getpixel((0, 0))[3], 0)
            self.assertGreater(result.getbbox()[2] - result.getbbox()[0], 0)
            opaque_pixels = [pixel for pixel in result.getdata() if pixel[3] == 255]
            self.assertTrue(opaque_pixels)
            self.assertTrue(any(pixel[0] > pixel[1] for pixel in opaque_pixels))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the test and verify the missing module failure**

Run:

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_chroma_key.py -v
```

Expected: FAIL because `tools.chroma_key` does not exist.

- [ ] **Step 3: Implement the tool**

Create `tools/chroma_key.py`:

```python
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image


KEY_GREEN = (0, 255, 0)


def _alpha_for_color(red: int, green: int, blue: int, source_alpha: int, inner: float, outer: float) -> int:
    distance = math.sqrt(
        (red - KEY_GREEN[0]) ** 2
        + (green - KEY_GREEN[1]) ** 2
        + (blue - KEY_GREEN[2]) ** 2
    )
    if distance <= inner:
        return 0
    if distance >= outer:
        return source_alpha
    blend = (distance - inner) / max(1.0, outer - inner)
    return round(source_alpha * blend)


def _remove_green(image: Image.Image, inner: float, outer: float) -> Image.Image:
    rgba = image.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    pixels = []
    for red, green, blue, alpha in rgba.getdata():
        keyed_alpha = _alpha_for_color(red, green, blue, alpha, inner, outer)
        if keyed_alpha < alpha:
            green = min(green, max(red, blue))
        pixels.append((red, green, blue, keyed_alpha))
    output.putdata(pixels)
    return output


def _normalize_canvas(image: Image.Image, canvas_size: int, padding: int) -> Image.Image:
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError("Chroma-key output contains no visible subject")
    subject = image.crop(bounds)
    available = max(1, canvas_size - padding * 2)
    scale = min(available / subject.width, available / subject.height)
    width = max(1, round(subject.width * scale))
    height = max(1, round(subject.height * scale))
    subject = subject.resize((width, height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((canvas_size - width) // 2, (canvas_size - height) // 2))
    return canvas


def process_image(
    input_path: Path,
    output_path: Path,
    inner: float = 18.0,
    outer: float = 96.0,
    canvas_size: int = 256,
    padding: int = 12,
) -> None:
    if inner < 0.0 or outer <= inner:
        raise ValueError("outer tolerance must be greater than inner tolerance")
    if canvas_size <= padding * 2:
        raise ValueError("canvas size must be larger than twice the padding")
    image = Image.open(input_path)
    keyed = _remove_green(image, inner, outer)
    normalized = _normalize_canvas(keyed, canvas_size, padding)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    normalized.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Remove a flat green screen and normalize a game asset canvas.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--inner", type=float, default=18.0)
    parser.add_argument("--outer", type=float, default=96.0)
    parser.add_argument("--canvas-size", type=int, default=256)
    parser.add_argument("--padding", type=int, default=12)
    arguments = parser.parse_args()
    process_image(
        arguments.input,
        arguments.output,
        inner=arguments.inner,
        outer=arguments.outer,
        canvas_size=arguments.canvas_size,
        padding=arguments.padding,
    )


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the focused test**

Run:

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_chroma_key.py -v
```

Expected: `OK`, with one passing test.

- [ ] **Step 5: Commit the tool**

```powershell
git add tools/chroma_key.py tests/tools/test_chroma_key.py
git commit -m "feat: add reusable chroma key asset tool"
```

---

### Task 2: Continuous Mixed Waves Through Minute Three

**Files:**
- Modify: `tests/test_game_database.gd`
- Modify: `data/waves/first_run.json`

**Interfaces:**
- Consumes: `GameDatabase.get_wave_events() -> Array[Dictionary]`.
- Produces: at least 17 events and 145 interval-spawned enemies from 0 through 180 seconds, using basic, charging, ranged, and elite roles with no event-time gap above 12 seconds.

- [ ] **Step 1: Add the failing three-minute density contract**

Add this call immediately after `_assert_early_wave_pressure(...)` in `tests/test_game_database.gd`:

```gdscript
	_assert_three_minute_wave_density(runner, db.get_wave_events())
```

Append this helper:

```gdscript
func _assert_three_minute_wave_density(runner, wave_events: Array[Dictionary]) -> void:
	var event_times: Array[float] = []
	var enemy_ids: Dictionary = {}
	var total_spawn_count := 0
	for event in wave_events:
		var event_time := float(event.get("time", 9999.0))
		if event_time > 180.0:
			continue
		event_times.append(event_time)
		enemy_ids[String(event.get("enemy_id", ""))] = true
		total_spawn_count += int(event.get("spawn_count", 0))
	event_times.sort()

	runner.assert_true(event_times.size() >= 17, "first three minutes should include at least seventeen wave events")
	runner.assert_true(total_spawn_count >= 145, "first three minutes should request at least 145 enemies")
	runner.assert_true(enemy_ids.has("basic_demon"), "first three minutes should include basic demons")
	runner.assert_true(enemy_ids.has("charging_demon"), "first three minutes should include charging demons")
	runner.assert_true(enemy_ids.has("ranged_demon"), "first three minutes should include ranged demons")
	runner.assert_true(enemy_ids.has("elite_guardian"), "first three minutes should introduce an elite")
	for index in range(1, event_times.size()):
		var gap := event_times[index] - event_times[index - 1]
		runner.assert_true(gap <= 12.0, "three-minute wave gap should not exceed 12 seconds")
```

- [ ] **Step 2: Run the Godot suite and verify the density failures**

Run:

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: FAIL because the current first three minutes contain too few events, too few enemies, no early elite, and gaps larger than 12 seconds.

- [ ] **Step 3: Replace the wave data**

Replace `data/waves/first_run.json` with:

```json
[
  { "time": 0, "enemy_id": "basic_demon", "spawn_count": 6, "spawn_interval": 0.65 },
  { "time": 10, "enemy_id": "basic_demon", "spawn_count": 8, "spawn_interval": 0.60 },
  { "time": 20, "enemy_id": "basic_demon", "spawn_count": 10, "spawn_interval": 0.55 },
  { "time": 30, "enemy_id": "charging_demon", "spawn_count": 3, "spawn_interval": 0.80 },
  { "time": 40, "enemy_id": "basic_demon", "spawn_count": 10, "spawn_interval": 0.50 },
  { "time": 50, "enemy_id": "ranged_demon", "spawn_count": 3, "spawn_interval": 0.85 },
  { "time": 60, "enemy_id": "basic_demon", "spawn_count": 12, "spawn_interval": 0.48 },
  { "time": 72, "enemy_id": "charging_demon", "spawn_count": 4, "spawn_interval": 0.70 },
  { "time": 84, "enemy_id": "basic_demon", "spawn_count": 12, "spawn_interval": 0.45 },
  { "time": 96, "enemy_id": "ranged_demon", "spawn_count": 4, "spawn_interval": 0.75 },
  { "time": 108, "enemy_id": "basic_demon", "spawn_count": 14, "spawn_interval": 0.42 },
  { "time": 120, "enemy_id": "charging_demon", "spawn_count": 5, "spawn_interval": 0.65 },
  { "time": 132, "enemy_id": "basic_demon", "spawn_count": 14, "spawn_interval": 0.40 },
  { "time": 144, "enemy_id": "ranged_demon", "spawn_count": 5, "spawn_interval": 0.70 },
  { "time": 156, "enemy_id": "basic_demon", "spawn_count": 16, "spawn_interval": 0.38 },
  { "time": 168, "enemy_id": "elite_guardian", "spawn_count": 1, "spawn_interval": 0.0 },
  { "time": 180, "enemy_id": "basic_demon", "spawn_count": 18, "spawn_interval": 0.35 },
  { "time": 240, "enemy_id": "charging_demon", "spawn_count": 8, "spawn_interval": 0.55 },
  { "time": 300, "enemy_id": "elite_guardian", "spawn_count": 1, "spawn_interval": 0.0 },
  { "time": 360, "enemy_id": "ranged_demon", "spawn_count": 10, "spawn_interval": 0.55 },
  { "time": 420, "enemy_id": "elite_guardian", "spawn_count": 2, "spawn_interval": 1.0 },
  { "time": 480, "enemy_id": "seal_boss", "spawn_count": 1, "spawn_interval": 0.0, "is_boss": true }
]
```

- [ ] **Step 4: Run the full Godot suite**

Run the command from Step 2.

Expected: `All tests passed.`

- [ ] **Step 5: Commit the wave contract**

```powershell
git add tests/test_game_database.gd data/waves/first_run.json
git commit -m "feat: sustain mixed combat through minute three"
```

---

### Task 3: Multi-Stat Upgrade Bundles

**Files:**
- Modify: `tests/test_upgrade_system.gd`
- Modify: `scripts/systems/upgrade_system.gd`
- Modify: `data/upgrades/core_upgrades.json`
- Modify: `tests/test_game_database.gd`

**Interfaces:**
- Consumes: upgrade definitions with `kind: "stat_bundle"` and `stat_modifiers: Dictionary`.
- Produces: aggregated runtime modifiers and comma-separated effect summaries using the existing stat formatting rules.

- [ ] **Step 1: Add failing bundle aggregation and summary coverage**

Insert before the final pickup-radius assertions in `tests/test_upgrade_system.gd`:

```gdscript
	var bundle_system = upgrade_system_script.new()
	var bundle_upgrades: Array[Dictionary] = [
		{
			"id": "heavy_seal",
			"display_name": "Heavy Seal",
			"kind": "stat_bundle",
			"stat_modifiers": {
				"weapon_damage_multiplier": 0.25,
				"move_speed": -10,
			},
			"max_stacks": 2,
		},
	]
	bundle_system.configure(bundle_upgrades)
	var bundle_choices = bundle_system.get_choices(runtime_state, 1, 77)
	runner.assert_eq(bundle_choices.size(), 1, "stat bundle should be a valid upgrade choice")
	runner.assert_eq(bundle_choices[0].get("effect_summary", ""), "Damage +25%, Speed -10", "stat bundle should summarize every modifier")
	var bundle_state := { "owned_weapons": {}, "upgrade_stacks": {} }
	bundle_system.apply_upgrade(bundle_state, bundle_choices[0])
	var bundle_modifiers = bundle_system.get_stat_modifiers(bundle_state)
	runner.assert_near(float(bundle_modifiers.get("weapon_damage_multiplier", 0.0)), 0.25, 0.001, "bundle damage modifier should apply")
	runner.assert_eq(bundle_modifiers.get("move_speed", 0), -10, "bundle speed tradeoff should apply")
```

Change the database upgrade count assertion in `tests/test_game_database.gd` to:

```gdscript
	runner.assert_true(db.get_upgrades().size() >= 18, "combat density foundation should include at least eighteen upgrades before the fifth weapon")
```

- [ ] **Step 2: Run the full Godot suite and verify failures**

Run the standard Godot test command.

Expected: FAIL because `stat_bundle` is not aggregated or summarized and the database has only 12 upgrades.

- [ ] **Step 3: Implement bundle aggregation**

Replace `get_stat_modifiers` in `scripts/systems/upgrade_system.gd` with:

```gdscript
func get_stat_modifiers(runtime_state: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var stacks: Dictionary = runtime_state.get("upgrade_stacks", {})

	for upgrade in upgrades:
		var id: String = upgrade.get("id", "")
		var stack_count := int(stacks.get(id, 0))
		if stack_count <= 0:
			continue
		var kind := String(upgrade.get("kind", ""))
		if kind == "stat":
			var stat: String = upgrade.get("stat", "")
			if stat != "":
				totals[stat] = float(totals.get(stat, 0.0)) + float(upgrade.get("value", 0.0)) * stack_count
		elif kind == "stat_bundle":
			var modifiers: Dictionary = upgrade.get("stat_modifiers", {})
			for stat in modifiers.keys():
				totals[stat] = float(totals.get(stat, 0.0)) + float(modifiers[stat]) * stack_count

	return _normalize_number_types(totals)
```

Replace `_build_effect_summary` and append the two helpers:

```gdscript
func _build_effect_summary(upgrade: Dictionary) -> String:
	var kind := String(upgrade.get("kind", ""))
	if kind == "weapon_level":
		return "Weapon Lv +1"
	if kind == "weapon_unlock":
		return "Unlock Weapon"
	if kind == "stat_bundle":
		var parts: Array[String] = []
		var modifiers: Dictionary = upgrade.get("stat_modifiers", {})
		for stat in modifiers.keys():
			var part := _build_stat_effect(String(stat), float(modifiers[stat]))
			if part != "":
				parts.append(part)
		return _join_effect_parts(parts)
	if kind == "stat":
		return _build_stat_effect(String(upgrade.get("stat", "")), float(upgrade.get("value", 0.0)))
	return ""

func _build_stat_effect(stat: String, value: float) -> String:
	match stat:
		"weapon_damage_multiplier":
			return "Damage %s" % _format_signed_value(value, true)
		"weapon_cooldown_multiplier":
			return "CD %s" % _format_signed_value(value, true)
		"pickup_radius":
			return "Pickup %s" % _format_signed_value(value, false)
		"move_speed":
			return "Speed %s" % _format_signed_value(value, false)
		"max_health":
			return "HP %s" % _format_signed_value(value, false)
		"material_gain":
			return "Mat %s" % _format_signed_value(value, true)
		"control_duration":
			return "Control %s" % _format_signed_value(value, true)
	return ""

func _join_effect_parts(parts: Array[String]) -> String:
	var result := ""
	for part in parts:
		if result != "":
			result += ", "
		result += part
	return result
```

- [ ] **Step 4: Append six bundle definitions**

Append these objects before the closing array bracket in `data/upgrades/core_upgrades.json`, preserving valid commas:

```json
  {
    "id": "quickstep_invocation",
    "display_name": "Quickstep Invocation",
    "kind": "stat_bundle",
    "stat_modifiers": { "weapon_cooldown_multiplier": -0.06, "move_speed": 12 },
    "max_stacks": 3
  },
  {
    "id": "heavy_seal",
    "display_name": "Heavy Seal",
    "kind": "stat_bundle",
    "stat_modifiers": { "weapon_damage_multiplier": 0.25, "move_speed": -10 },
    "max_stacks": 2
  },
  {
    "id": "prosperity_compass",
    "display_name": "Prosperity Compass",
    "kind": "stat_bundle",
    "stat_modifiers": { "pickup_radius": 32, "material_gain": 0.10 },
    "max_stacks": 3
  },
  {
    "id": "iron_focus",
    "display_name": "Iron Focus",
    "kind": "stat_bundle",
    "stat_modifiers": { "max_health": 10, "weapon_damage_multiplier": 0.10 },
    "max_stacks": 3
  },
  {
    "id": "wind_edge",
    "display_name": "Wind Edge",
    "kind": "stat_bundle",
    "stat_modifiers": { "move_speed": 18, "weapon_damage_multiplier": 0.10 },
    "max_stacks": 3
  },
  {
    "id": "gathering_breath",
    "display_name": "Gathering Breath",
    "kind": "stat_bundle",
    "stat_modifiers": { "weapon_cooldown_multiplier": -0.04, "pickup_radius": 16 },
    "max_stacks": 3
  }
```

- [ ] **Step 5: Run focused and full tests**

Run the standard Godot test command.

Expected: `All tests passed.`

- [ ] **Step 6: Commit upgrade bundles**

```powershell
git add tests/test_upgrade_system.gd tests/test_game_database.gd scripts/systems/upgrade_system.gd data/upgrades/core_upgrades.json
git commit -m "feat: add multi-stat runtime upgrades"
```

---

### Task 4: Radial Spirit Needle Array

**Files:**
- Modify: `tests/test_combat_resolver.gd`
- Modify: `scripts/systems/combat_resolver.gd`
- Modify: `tests/test_weapon_system.gd`
- Modify: `tests/test_game_database.gd`
- Modify: `scripts/systems/weapon_system.gd`
- Modify: `scripts/core/game_loop.gd`
- Create: `data/weapons/spirit_needle_array.json`
- Modify: `data/upgrades/core_upgrades.json`

**Interfaces:**
- Consumes: weapon fire-event field `aim_mode: "radial"`.
- Produces: `CombatResolver.build_radial_directions(count: int, start_angle: float = 0.0) -> Array[Vector2]` and radial fire events with six to twelve evenly spaced projectiles.

- [ ] **Step 1: Add failing radial geometry tests**

Insert in `tests/test_combat_resolver.gd` after spread-direction assertions:

```gdscript
	var radial_directions = resolver.build_radial_directions(4, 0.0)
	runner.assert_eq(radial_directions.size(), 4, "resolver should build one radial direction per projectile")
	runner.assert_eq(radial_directions[0], Vector2.RIGHT, "radial pattern should honor its start angle")
	runner.assert_near(radial_directions[1].angle(), PI / 2.0, 0.001, "radial directions should be evenly spaced")
```

- [ ] **Step 2: Add failing Spirit Needle event tests**

Insert before final cleanup in `tests/test_weapon_system.gd`:

```gdscript
	runner.assert_true(db.has_weapon("spirit_needle_array"), "database should include Spirit Needle Array")
	if db.has_weapon("spirit_needle_array"):
		var needle_system = weapon_system_script.new()
		needle_system.add_weapon(db.get_weapon("spirit_needle_array"))
		var needle_events = needle_system.tick(1.3)
		runner.assert_eq(needle_events.size(), 1, "Spirit Needle Array should fire after its base cooldown")
		if not needle_events.is_empty():
			runner.assert_eq(needle_events[0].get("aim_mode", ""), "radial", "Spirit Needle Array should use radial aiming")
			runner.assert_eq(needle_events[0].get("projectile_count", 0), 6, "Spirit Needle Array should start with six needles")
			runner.assert_eq(needle_events[0].get("projectile_texture_path", ""), "res://art/weapons/spirit_needle_array/spirit_needle_projectile.png", "Spirit Needle Array should identify its production projectile")
		needle_system.level_weapon("spirit_needle_array")
		needle_system.level_weapon("spirit_needle_array")
		var level_three_events = needle_system.tick(1.3)
		if not level_three_events.is_empty():
			runner.assert_eq(level_three_events[0].get("projectile_count", 0), 8, "Spirit Needle Array level three should fire eight needles")
		needle_system.free()
```

Change the content assertions in `tests/test_game_database.gd` to:

```gdscript
	runner.assert_true(db.has_weapon("spirit_needle_array"), "database should include spirit_needle_array")
	runner.assert_true(db.get_weapons().size() >= 5, "combat density foundation should include five weapons")
	runner.assert_true(db.get_upgrades().size() >= 20, "combat density foundation should include at least twenty upgrades")
```

- [ ] **Step 3: Run the Godot suite and verify failures**

Run the standard Godot test command.

Expected: FAIL because radial geometry, the fifth weapon, visual event fields, and its upgrades do not exist.

- [ ] **Step 4: Implement radial geometry**

Append to `scripts/systems/combat_resolver.gd`:

```gdscript
func build_radial_directions(count: int, start_angle: float = 0.0) -> Array[Vector2]:
	var safe_count: int = max(1, count)
	var result: Array[Vector2] = []
	var step := TAU / float(safe_count)
	for index in range(safe_count):
		result.append(Vector2.RIGHT.rotated(start_angle + step * index))
	return result
```

- [ ] **Step 5: Include aim and visual metadata in fire events**

Add these entries to the dictionary returned by `_build_fire_event` in `scripts/systems/weapon_system.gd`:

```gdscript
		"aim_mode": definition.get("aim_mode", "target"),
		"projectile_texture_path": definition.get("projectile_texture_path", ""),
		"projectile_scale": float(definition.get("projectile_scale", 0.08)),
		"projectile_tint": definition.get("projectile_tint", "#ffffff"),
```

- [ ] **Step 6: Route radial fire events in GameLoop**

Replace `_spawn_projectiles` in `scripts/core/game_loop.gd` with:

```gdscript
func _spawn_projectiles(event: Dictionary) -> void:
	var enemies = get_tree().get_nodes_in_group(GameConstantsScript.ENEMY_GROUP)
	if enemies.is_empty() or projectile_scene == null:
		return

	var count := int(event.get("projectile_count", 1))
	var directions: Array[Vector2] = []
	if String(event.get("aim_mode", "target")) == "radial":
		directions = combat_resolver.build_radial_directions(count, run_time * 0.8)
	else:
		var target = combat_resolver.find_closest_enemy(player.global_position, enemies, float(event.get("range", 320.0)))
		if target == null:
			return
		var direction: Vector2 = player.global_position.direction_to(target.global_position)
		directions = combat_resolver.build_spread_directions(direction, count, 8.0)

	for projectile_direction in directions:
		var projectile = projectile_scene.instantiate()
		add_child(projectile)
		projectile.global_position = player.global_position
		if projectile.has_method("configure_from_event"):
			projectile.configure_from_event(projectile_direction, event)
		else:
			projectile.configure(projectile_direction, float(event["projectile_speed"]), int(event["damage"]))
```

- [ ] **Step 7: Add the fifth weapon definition**

Create `data/weapons/spirit_needle_array.json`:

```json
{
  "id": "spirit_needle_array",
  "display_name": "Spirit Needle Array",
  "description": "Releases a rotating ring of spirit needles to break surrounding swarms.",
  "type": "projectile",
  "aim_mode": "radial",
  "base_damage": 4,
  "cooldown": 1.2,
  "projectile_speed": 520,
  "projectile_count": 6,
  "range": 300,
  "pierce": 0,
  "projectile_texture_path": "res://art/weapons/spirit_needle_array/spirit_needle_projectile.png",
  "projectile_scale": 0.10,
  "projectile_tint": "#d8b4ff",
  "max_level": 5,
  "level_modifiers": [
    { "level": 2, "base_damage": 6 },
    { "level": 3, "projectile_count": 8 },
    { "level": 4, "pierce": 1 },
    { "level": 5, "projectile_count": 12, "cooldown": 0.9 }
  ]
}
```

- [ ] **Step 8: Add unlock and level upgrades**

Append these entries to `data/upgrades/core_upgrades.json`:

```json
  {
    "id": "spirit_needle_array_level",
    "display_name": "Spirit Needle Array Mastery",
    "kind": "weapon_level",
    "weapon_id": "spirit_needle_array",
    "max_stacks": 4
  },
  {
    "id": "unlock_spirit_needle_array",
    "display_name": "Build Spirit Needle Array",
    "kind": "weapon_unlock",
    "weapon_id": "spirit_needle_array",
    "max_stacks": 1
  }
```

- [ ] **Step 9: Run the full Godot suite**

Run the standard Godot test command.

Expected: `All tests passed.` The texture path may not exist until Task 5, but this task only validates event metadata.

- [ ] **Step 10: Commit the radial weapon**

```powershell
git add tests/test_combat_resolver.gd tests/test_weapon_system.gd tests/test_game_database.gd scripts/systems/combat_resolver.gd scripts/systems/weapon_system.gd scripts/core/game_loop.gd data/weapons/spirit_needle_array.json data/upgrades/core_upgrades.json
git commit -m "feat: add radial Spirit Needle Array"
```

---

### Task 5: Production Projectile Visuals

**Files:**
- Modify: `tests/test_projectile.gd`
- Modify: `tests/test_game_database.gd`
- Modify: `scripts/weapons/projectile.gd`
- Modify: `data/weapons/flying_sword.json`
- Modify: `data/weapons/talisman_fire.json`
- Modify: `data/weapons/mechanism_crossbow.json`
- Create: `art/source_green/weapon_spirit_needle_projectile_green.png`
- Create: `art/source_green/weapon_talisman_fire_projectile_green.png`
- Create: `art/source_green/weapon_mechanism_bolt_projectile_green.png`
- Create: `art/source_green/icon_spirit_needle_array_green.png`
- Create: `art/weapons/spirit_needle_array/spirit_needle_projectile.png`
- Create: `art/weapons/talisman_fire/talisman_fire_projectile.png`
- Create: `art/weapons/mechanism_crossbow/mechanism_bolt_projectile.png`
- Create: `art/icons/icon_spirit_needle_array.png`

**Interfaces:**
- Consumes: fire-event keys `projectile_texture_path`, `projectile_scale`, and `projectile_tint`.
- Produces: a configured `Sprite2D` using a validated production texture, stable scale, and HTML tint.

- [ ] **Step 1: Add failing projectile visual tests**

In `tests/test_projectile.gd`, add a child before calling `configure_from_event`:

```gdscript
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	projectile.add_child(sprite)
```

Add these keys to the test event:

```gdscript
		"projectile_texture_path": "res://art/weapons/flying_sword/flying_sword_projectile.png",
		"projectile_scale": 0.12,
		"projectile_tint": "#d8b4ff",
```

Add these assertions after range assertions:

```gdscript
		runner.assert_true(sprite.texture != null, "projectile event should load its visual texture")
		runner.assert_eq(sprite.texture.resource_path, "res://art/weapons/flying_sword/flying_sword_projectile.png", "projectile event should select its texture")
		runner.assert_eq(sprite.scale, Vector2(0.12, 0.12), "projectile event should select its visual scale")
		runner.assert_eq(sprite.modulate, Color.html("#d8b4ff"), "projectile event should apply its tint")
```

Add to `tests/test_game_database.gd` after weapon-count assertions:

```gdscript
	for weapon_id in ["flying_sword", "talisman_fire", "mechanism_crossbow", "spirit_needle_array"]:
		var texture_path := String(db.get_weapon(weapon_id).get("projectile_texture_path", ""))
		runner.assert_true(texture_path != "", "%s should declare a projectile texture" % weapon_id)
		runner.assert_true(ResourceLoader.exists(texture_path), "%s projectile texture should exist" % weapon_id)
```

- [ ] **Step 2: Run the Godot suite and verify failures**

Run the standard Godot test command.

Expected: FAIL because projectile visuals are ignored and three production textures do not exist.

- [ ] **Step 3: Apply visual metadata in Projectile**

Add this call to the end of `configure_from_event` in `scripts/weapons/projectile.gd`:

```gdscript
	_configure_visual(event)
```

Append:

```gdscript
func _configure_visual(event: Dictionary) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var texture_path := String(event.get("projectile_texture_path", ""))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)
	var visual_scale := max(0.01, float(event.get("projectile_scale", 0.08)))
	sprite.scale = Vector2(visual_scale, visual_scale)
	var tint_text := String(event.get("projectile_tint", "#ffffff"))
	if Color.html_is_valid(tint_text):
		sprite.modulate = Color.html(tint_text)
```

- [ ] **Step 4: Generate four green-screen source assets with image-2**

Generate each image separately and save it at the exact source path listed above. Use these prompts:

```text
Spirit Needle projectile: mobile 2D game pixel art asset, one slender violet-and-gold spiritual needle projectile pointing horizontally to the right, strong readable silhouette, bright violet energy core, crisp pixel edges, centered with generous padding, perfectly flat solid #00ff00 chroma-key background, no shadow, no floor, no gradient in background, no text, no watermark, do not use #00ff00 in the subject.
```

```text
Talisman Fire projectile: mobile 2D game pixel art asset, one burning eastern talisman projectile pointing horizontally to the right, red paper seal with gold glyph-like decorative marks and compact orange flame trail, crisp readable silhouette, centered with generous padding, perfectly flat solid #00ff00 chroma-key background, no shadow, no floor, no gradient in background, no text, no watermark, do not use #00ff00 in the subject.
```

```text
Mechanism bolt projectile: mobile 2D game pixel art asset, one compact bronze-and-blue mechanism crossbow bolt pointing horizontally to the right, metal fins and cyan energy tip, crisp readable silhouette, centered with generous padding, perfectly flat solid #00ff00 chroma-key background, no shadow, no floor, no gradient in background, no text, no watermark, do not use #00ff00 in the subject.
```

```text
Spirit Needle Array icon: square mobile 2D game pixel art icon, six violet-and-gold spiritual needles arranged in a circular formation around a small glowing seal, crisp high-contrast silhouette readable at 64 pixels, centered with generous padding, perfectly flat solid #00ff00 chroma-key background, no frame, no shadow, no floor, no text, no watermark, do not use #00ff00 in the subject.
```

- [ ] **Step 5: Convert source assets to normalized transparent PNGs**

Run:

```powershell
$python = 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $python tools/chroma_key.py art/source_green/weapon_spirit_needle_projectile_green.png art/weapons/spirit_needle_array/spirit_needle_projectile.png --canvas-size 256 --padding 12
& $python tools/chroma_key.py art/source_green/weapon_talisman_fire_projectile_green.png art/weapons/talisman_fire/talisman_fire_projectile.png --canvas-size 256 --padding 12
& $python tools/chroma_key.py art/source_green/weapon_mechanism_bolt_projectile_green.png art/weapons/mechanism_crossbow/mechanism_bolt_projectile.png --canvas-size 256 --padding 12
& $python tools/chroma_key.py art/source_green/icon_spirit_needle_array_green.png art/icons/icon_spirit_needle_array.png --canvas-size 256 --padding 16
```

Expected: four 256 x 256 transparent PNG files with no visible green corners.

- [ ] **Step 6: Wire distinct textures into weapon definitions**

Add to `data/weapons/flying_sword.json`:

```json
  "projectile_texture_path": "res://art/weapons/flying_sword/flying_sword_projectile.png",
  "projectile_scale": 0.08,
  "projectile_tint": "#ffffff",
```

Add to `data/weapons/talisman_fire.json`:

```json
  "projectile_texture_path": "res://art/weapons/talisman_fire/talisman_fire_projectile.png",
  "projectile_scale": 0.10,
  "projectile_tint": "#fff2dc",
```

Add to `data/weapons/mechanism_crossbow.json`:

```json
  "projectile_texture_path": "res://art/weapons/mechanism_crossbow/mechanism_bolt_projectile.png",
  "projectile_scale": 0.09,
  "projectile_tint": "#e5f6ff",
```

- [ ] **Step 7: Import assets and run full tests**

Run:

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --editor --path . --quit-after 2
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: import exits successfully, then `All tests passed.`

- [ ] **Step 8: Visually inspect all four final PNGs**

Open each final file at original resolution and verify:

- transparent corners;
- no green fringe around the silhouette;
- projectile points to the right so rotation follows velocity;
- subject fits inside the 256 x 256 canvas;
- icon remains readable at 64 x 64.

- [ ] **Step 9: Commit production visuals**

```powershell
git add tests/test_projectile.gd tests/test_game_database.gd scripts/weapons/projectile.gd data/weapons/flying_sword.json data/weapons/talisman_fire.json data/weapons/mechanism_crossbow.json art/source_green art/weapons/spirit_needle_array art/weapons/talisman_fire art/weapons/mechanism_crossbow art/icons/icon_spirit_needle_array.png
git commit -m "feat: add distinct production projectile visuals"
```

---

### Task 6: Full Verification, Visual Smoke, and Publication

**Files:**
- Verify all modified files from Tasks 1-5.

**Interfaces:**
- Consumes: current `main` working tree.
- Produces: passing Python and Godot tests, a clean scene smoke run, a visible playable Godot process, and pushed commits on `origin/main`.

- [ ] **Step 1: Run the Python asset-tool test**

```powershell
& 'C:\Users\Nothin\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tests/tools/test_chroma_key.py -v
```

Expected: `OK`.

- [ ] **Step 2: Run all Godot tests**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . -s res://tests/run_all_tests.gd
```

Expected: `All tests passed.`

- [ ] **Step 3: Run a headless game-scene smoke test**

```powershell
& 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit-after 180
```

Expected: process exits with code 0 and no script errors.

- [ ] **Step 4: Inspect repository state**

```powershell
git status --short --branch
git log -6 --oneline --decorate
git diff --check
```

Expected: no unstaged implementation changes and the task commits are visible at `HEAD`.

- [ ] **Step 5: Push main**

```powershell
git -c http.proxy=http://127.0.0.1:7897 -c https.proxy=http://127.0.0.1:7897 -c http.version=HTTP/1.1 -c core.compression=9 push --progress origin main
```

Expected: `main -> main` or `Everything up-to-date`.

- [ ] **Step 6: Launch the playable game visibly**

```powershell
Start-Process -FilePath 'C:\Users\Nothin\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe' -ArgumentList '--path', '.'
```

Expected: a visible `Fuji Xingzhe (DEBUG)` game window with immediate enemies, automatic Flying Sword attacks, richer upgrade choices, and Spirit Needle Array available as an unlock.

---

## Plan Self-Review

- Spec coverage: this plan implements sub-project 1 from the approved 40-hour design: sustained three-minute pressure, a richer upgrade pool, a fifth weapon, and projectile visual differentiation.
- Scope boundary: encounter budgets, object pooling, action-frame contracts, additional chapters, and the remaining eleven weapons stay in their separately planned sub-projects.
- Type consistency: all radial functions return `Array[Vector2]`; all weapon visual event keys use the `projectile_` prefix consistently from JSON through `WeaponSystem` to `Projectile`.
- Content consistency: Task 3 raises the pool from 12 to 18 upgrades; Task 4 adds two Spirit Needle entries and raises it to 20.
- Verification consistency: every code or data task starts with a failing assertion and ends with the full Godot suite; image processing also has an independent Pillow test.
