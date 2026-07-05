# Asset Prompt Manifest

## Shared Cutout Constraints

Use case: stylized-concept
Asset type: mobile 2D game pixel art asset
Style/medium: 3/4 top-down pixel art, crisp silhouette, readable at small mobile size
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background
Constraints: no shadows, no cast shadow, no contact shadow, no gradients, no texture in the background, no floor plane, no reflection, no watermark, no text, generous padding, subject fully separated from background, do not use #00ff00 anywhere in the subject
Avoid: blur, painterly smearing, realistic photo rendering, tiny unreadable details, cropped subject

## First Batch Prompts

### Player: Artificer Cultivator Front Walk Frame

Create a 3/4 top-down pixel art sprite of an eastern fantasy artificer cultivator in talisman robes with subtle brass mechanism details, front-facing walk pose, compact mobile-game proportions, clean readable silhouette.

### Player: Artificer Cultivator Back Walk Frame

Create a 3/4 top-down pixel art sprite of the same eastern fantasy artificer cultivator from the back, talisman robe silhouette and small brass mechanism details visible, compact mobile-game proportions, clean readable silhouette.

### Enemy: Small Demon Move Frame

Create a 3/4 top-down pixel art sprite of a small eastern fantasy demon minion, hunched body, horned silhouette, dark red and charcoal colors, simple readable shape for survivor-game swarms.

### Weapon: Flying Sword Projectile

Create a 3/4 top-down pixel art sprite of a talisman-guided flying sword projectile, silver blade with warm gold talisman strip, crisp outline, readable at small size.

## Generated Batch 1

Generator: internal image-2
Post process: chroma-key removal from flat green-screen source images into transparent PNG assets.

### Source Green-Screen Sheets

- `res://art/source_green/player_artificer_sheet_green.png`
- `res://art/source_green/enemy_small_demon_sheet_green.png`
- `res://art/source_green/weapon_flying_sword_sheet_green.png`
- `res://art/source_green/ui_icon_sheet_green.png`

### Final Transparent Assets

- Player: `res://art/characters/player/player_front.png`, `player_back.png`, `player_right.png`, `player_left.png`, `player_hit.png`, `player_defeated.png`
- Small demon: `res://art/enemies/small_demon/small_demon_front.png`, `small_demon_side.png`, `small_demon_hit.png`, `small_demon_defeated.png`
- Flying sword: `res://art/weapons/flying_sword/flying_sword_projectile.png`, `flying_sword_orbit.png`, `flying_sword_hit_spark.png`, `flying_sword_slash_trail.png`
- Icons: `res://art/icons/icon_flying_sword.png`, `icon_talisman_fire.png`, `icon_mechanism_crossbow.png`, `icon_demon_sealing_bell.png`, `icon_spirit_stone.png`, `icon_talisman_paper.png`, `icon_mechanism_part.png`, `icon_jade_compass.png`

### Scene Integration

- Player scene uses `player_front.png`.
- Basic demon scene uses `small_demon_front.png`.
- Projectile scene uses `flying_sword_projectile.png`.
- Experience pickup scene uses `icon_spirit_stone.png`.
