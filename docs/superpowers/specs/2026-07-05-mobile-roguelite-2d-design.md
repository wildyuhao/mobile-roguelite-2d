# Mobile 2D Roguelite Design

## Project Summary

The project is a simple but complete vertical-slice mobile 2D survivor roguelite built with Godot 4, GDScript, and data-driven content configuration. The game targets native mobile first, with Android as the first export target and iOS kept as a later packaging route.

Working title: `Fuji Xingzhe`

Core fantasy: the player controls an artificer cultivator who combines talismans, flying swords, and mechanical devices to survive waves of monsters in an eastern fantasy wasteland.

The first playable vertical slice should feel like a compact finished game loop rather than a throwaway prototype. It should include movement, automatic combat, enemy waves, level-up choices, equipment, basic meta progression, save data, a boss fight, and final art assets generated for production use.

## Confirmed Direction

- Platform: native mobile, Android first.
- Engine: Godot 4.
- Language: GDScript.
- Gameplay style: survivor-like automatic combat.
- Theme: eastern talisman and mechanism fantasy.
- Scope: 2-3 week vertical slice.
- Repository: `wildyuhao/mobile-roguelite-2d`.
- Visibility: public GitHub repository.
- Art direction: final 3/4 top-down pixel art assets, not temporary placeholders.
- Image generation: use `gpt-image-2` to create flat green-screen source images, then remove the chroma key locally into transparent PNG assets.

## Core Experience

The player moves with a mobile virtual joystick while weapons attack automatically. Monsters spawn continuously around the player. Defeated enemies drop spirit energy and materials. Collecting enough spirit energy triggers a pause and shows three upgrade choices. The run escalates from basic monster pressure, to elite threats, to a final boss encounter.

Target single-run length for the vertical slice: 8-10 minutes.

The player should feel three things quickly:

- Movement matters because enemy pressure and charging enemies force positioning.
- Builds matter because weapons and upgrades change attack patterns.
- Progression matters because materials and equipment make later runs stronger.

## Vertical Slice Content

### Player

One playable character:

- Name: artificer cultivator.
- Role: balanced starter character.
- Base kit: medium movement speed, medium health, starts with `Flying Sword`.
- Visual identity: small 3/4 top-down pixel character with talisman robes, mechanical ornamentation, and clean silhouette readability.

### Weapons

The vertical slice includes four weapons:

1. `Flying Sword`
   - Auto-targets nearby enemies.
   - Starts as single projectile slashes.
   - Upgrades add additional swords, cooldown reduction, piercing, and orbit behavior.

2. `Talisman Fire`
   - Launches fire talismans that explode on impact.
   - Upgrades add area size, burn duration, and multi-shot.

3. `Mechanism Crossbow`
   - Fires bolts toward the closest enemy or in a narrow cone.
   - Upgrades add projectile count, piercing, and attack speed.

4. `Demon-Sealing Bell`
   - Emits periodic soundwave rings around the player.
   - Upgrades add knockback, slow, stun chance, and ring count.

### Weapon Evolutions

The first version should include 2-3 explicit evolution recipes rather than a complex open-ended crafting system.

Initial recipes:

- `Flying Sword` + `Talisman Fire` => `Burning Sword Array`
- `Mechanism Crossbow` + `Demon-Sealing Bell` => `Binding Volley`
- `Demon-Sealing Bell` + defensive passive => `Guardian Bell Field`

These evolutions provide a long-term content pattern: future updates can add weapons, passives, and recipe combinations without rebuilding the combat system.

### Upgrades

The level-up screen shows three choices. Choices can be:

- New weapon.
- Existing weapon level.
- Passive stat upgrade.
- Evolution when recipe requirements are met.

Initial upgrade pool:

- Weapon damage.
- Weapon cooldown reduction.
- Projectile count.
- Projectile piercing.
- Attack range.
- Area size.
- Critical chance.
- Movement speed.
- Pickup radius.
- Max health.
- Shield recharge.
- Material gain bonus.

### Equipment

The vertical slice includes six equipment items for meta progression:

- `Talisman Robe`: max health and damage reduction.
- `Jade Compass`: pickup radius and material gain.
- `Bronze Gear Core`: weapon cooldown reduction.
- `Cloudstep Boots`: movement speed.
- `Sword Gourd`: starts with or improves Flying Sword.
- `Bell Charm`: improves crowd-control effects.

Equipment should be simple at first: fixed stats and upgrade levels. The vertical slice should not include randomized loot affixes, gacha, or complex rarity systems.

### Enemies

The vertical slice includes four normal enemy types and one boss:

- `Small Demon`: basic swarming enemy.
- `Charging Demon`: lines up and rushes at the player.
- `Ranged Demon`: keeps distance and fires slow projectiles.
- `Elite Guardian`: stronger enemy that appears in timed pressure waves.
- `Boss`: multi-phase enemy with movement, area attacks, summons, and a final burst phase.

### Map

The vertical slice uses one large eastern wasteland map:

- Loopable ground texture.
- Sparse obstacles such as stone tablets, broken pillars, dead trees, broken altar pieces, and mechanism wreckage.
- No procedural map generation in the first slice.
- Boss arena boundaries can be expressed through a talisman field or sealing circle.

## Game Architecture

The project should follow this rule:

Scenes own presentation. Systems own rules. Data owns content.

Recommended structure:

```text
res://
  scenes/
    boot/
    game/
    player/
    enemies/
    weapons/
    ui/
  scripts/
    core/
    systems/
    components/
    data/
  data/
    weapons/
    upgrades/
    enemies/
    equipment/
    waves/
  art/
    characters/
    enemies/
    weapons/
    effects/
    icons/
    environment/
    ui/
  audio/
  tests/
docs/
  superpowers/specs/
```

### Core Modules

`GameLoop`

- Owns run state, run timer, pause state, win/loss state, boss spawn timing, and post-run settlement.

`Player`

- Owns movement, health, damage intake, experience pickup, and stat aggregation.

`WeaponSystem`

- Loads weapon definitions and manages automatic firing.
- Supports projectiles, orbiting weapons, periodic area pulses, cooldowns, piercing, damage, and targeting rules.

`EnemyDirector`

- Loads wave definitions and spawns enemies according to run time, player position, and pressure budget.
- Introduces elites and the boss at defined timings.

`UpgradeSystem`

- Builds the available upgrade pool from owned weapons, passives, and evolution requirements.
- Presents three choices on level-up.
- Applies the selected upgrade to player stats, weapon state, or evolution state.

`EquipmentSystem`

- Loads equipped items before a run.
- Applies base stat modifiers and starting bonuses.
- Supports equipment upgrade levels in meta progression.

`SaveSystem`

- Saves materials, equipment levels, permanent talents, settings, and first-run tutorial flags.

## Data Flow

1. Boot scene loads save data.
2. Main menu reads equipment and player progression.
3. Starting a run loads character, equipped items, base weapon, weapon definitions, upgrade definitions, enemy definitions, and wave definitions.
4. Runtime stats are assembled from character base stats, equipment, and run upgrades.
5. Enemy deaths drop experience and materials.
6. Experience pickup increases the player level.
7. Level-up pauses gameplay and asks `UpgradeSystem` for three valid choices.
8. The chosen upgrade mutates weapon state, passive stats, or evolution state.
9. Boss defeat or player death ends the run.
10. Settlement converts run rewards into saved materials and progression updates.

## Error Handling And Scope Control

The first vertical slice should avoid systems that would slow down the core loop:

- No procedural map generation.
- No online account system.
- No ads or in-app purchases.
- No leaderboards.
- No randomized equipment affixes.
- No complex gacha or rarity economy.
- No iOS signing work in the first slice.

Configuration loading should fail loudly in development. Missing weapon, enemy, wave, or upgrade definitions should print clear errors with data ids. During export, invalid data should prevent packaging rather than silently producing broken runs.

## Testing And Validation

Automated or semi-automated validation should cover:

- Weapon definitions load successfully.
- Upgrade definitions load successfully.
- Enemy and wave definitions load successfully.
- Upgrade selection can always produce three valid choices when the pool is large enough.
- Weapon cooldowns advance predictably.
- Save data can be created, loaded, changed, and saved again.

Manual acceptance should cover:

- Mobile aspect ratio and safe areas.
- Virtual joystick comfort.
- Enemy density under load.
- Upgrade screen readability.
- Boss attack visibility.
- Asset clarity on small screens.
- Android export path.

## Art Production Plan

Final assets should be generated rather than drawn as temporary placeholders. The style is 3/4 top-down pixel art with eastern talisman and mechanism fantasy design.

The source generation process:

1. Generate assets with `gpt-image-2`.
2. Use a perfectly flat `#00ff00` chroma-key background.
3. Require no shadows, no gradients, no floor plane, no reflections, no text, and no watermark.
4. Avoid using `#00ff00` anywhere in the subject.
5. Keep the subject fully separated from the background with generous padding.
6. Remove the green screen locally to create transparent PNGs.
7. Store final transparent assets inside `res://art/...`.

### First Art Batch

Generate in this order:

1. Player character
   - Walk frames: front, back, left, right.
   - Hit frame.
   - Death frame.
   - Portrait or half-body art for menu screens.

2. Enemies
   - Small Demon: move and hit frames.
   - Charging Demon: move and charge frames.
   - Ranged Demon: move and cast frames.
   - Elite Guardian: move and hit frames.
   - Boss: idle, move, attack 1, attack 2, hit, death.

3. Weapons and projectiles
   - Flying Sword projectile, orbit state, hit effect.
   - Talisman Fire talisman, fireball, explosion.
   - Mechanism Crossbow, bolt, rapid-fire effect.
   - Demon-Sealing Bell, soundwave ring, binding seal.

4. Icons
   - Four weapon icons.
   - 8-12 upgrade icons.
   - Six equipment icons.
   - Spirit stone, talisman paper, mechanism part.

5. Environment
   - Wasteland ground texture.
   - Ruin ground texture.
   - Stone tablet.
   - Broken pillar.
   - Dead tree.
   - Broken altar piece.
   - Mechanism wreckage.
   - Boss sealing circle.

6. UI art
   - Title art.
   - Health icon.
   - Experience icon.
   - Material icon.
   - Pause icon.
   - Upgrade card frame.
   - Equipment slot frame.
   - Button frame.
   - Settlement panel frame.

### Shared Image Prompt Requirements

All cutout assets should include the following constraints:

```text
Use case: stylized-concept
Asset type: mobile 2D game pixel art asset
Style/medium: 3/4 top-down pixel art, crisp silhouette, readable at small mobile size
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background
Constraints: no shadows, no cast shadow, no contact shadow, no gradients, no texture in the background, no floor plane, no reflection, no watermark, no text, generous padding, subject fully separated from background, do not use #00ff00 anywhere in the subject
Avoid: blur, painterly smearing, realistic photo rendering, tiny unreadable details, cropped subject
```

## Milestones

### Week 1: Core Playable Loop

- Create Godot project structure.
- Implement boot, menu, and run scene flow.
- Implement mobile virtual joystick.
- Implement player movement and camera.
- Implement enemy movement and health.
- Implement basic spawning.
- Implement experience drops and level-up trigger.
- Implement first weapon: Flying Sword.
- Import first player and enemy assets.

Acceptance: the player can move, enemies chase, the weapon kills enemies, experience drops, and level-up appears.

### Week 2: Build System And Content

- Implement all four weapons.
- Implement upgrade choices.
- Implement passive stat upgrades.
- Implement first evolution recipes.
- Implement four enemy types.
- Implement wave timings.
- Implement equipment definitions.
- Implement material drops.
- Import first-pass weapon, enemy, icon, and environment assets.

Acceptance: an 8-10 minute run has visible build growth and escalating enemy pressure.

### Week 3: Boss, Meta, Polish, Export

- Implement boss encounter.
- Implement run settlement.
- Implement save data.
- Implement equipment upgrades.
- Implement UI screens for menu, equipment, run HUD, upgrade choices, and settlement.
- Add performance checks for enemy density.
- Export Android build.
- Polish assets and effects.

Acceptance: the vertical slice can be played on Android from menu to run to boss to settlement to meta upgrade.

## Future Iteration Ideas

- More characters with different starting weapons and passive traits.
- More weapon evolution recipes.
- Talisman field terrain effects.
- Summoned mechanism beasts.
- Boss-specific reward materials.
- Equipment set bonuses.
- Daily challenge seed.
- Endless mode after boss clear.
- Additional biomes such as bamboo ruin, ghost market, and thunder altar.
- Lightweight narrative events between runs.

## Fixed Defaults

The following defaults are intentionally fixed for the vertical slice:

- Android first, iOS later.
- Final generated art assets, not placeholder art.
- Local save only.
- No monetization.
- No online services.
- Fixed map, not procedural generation.
- Simple equipment levels, not randomized affixes.
