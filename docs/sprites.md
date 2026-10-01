# Sprite register

The game's look: the fixed rules every sprite obeys (the **style sheet**) and one entry per sprite (the **sprite list**). AI tools take this file as context, so every asset comes out consistent with the others. Decided in [#6](https://github.com/klusignolo/GameJam2026/issues/6); background research in `docs/research/sprite-pipeline.md` on the [`research/sprite-pipeline`](https://github.com/klusignolo/GameJam2026/tree/research/sprite-pipeline) branch.

Like `docs/tuning.md`, this is a living register: when a proof or playtest changes a rule or a sprite, update its entry and add a note. Sizes that are gameplay (vehicle footprints) also live in `docs/tuning.md`.

**Not yet proven.** The legibility rules below (outline, shadow, mipmaps at 0.45× zoom) are untested. The pipeline-proof ticket that follows #6 tests them; its fallbacks are noted inline.

## Style sheet

### Projection and resolution

- **Top-down world, ¾-view characters.** Roads, vehicles, decals and rooftops are seen straight down. The Raccoon and Light poles are drawn in ¾ view (Zelda/Stardew style).
- **Base resolution 1280×720,** Godot `canvas_items` stretch, aspect expand. The cabinet resolution is unknown; the base only sets coordinate units.
- **Author every texture at 2×** the world size listed here, import with mipmaps on and a Linear Mipmap filter (the camera zooms out to ~0.45×).
- **Units:** all sizes in this file are world px at 1× unless marked "@2×".

### Medium

- **Flat vector SVG,** written by Claude. No pixel art (it shimmers under zoom and rotation).
- **Fallback:** if the SVG Raccoon lacks charm in the proof, the Raccoon alone moves to Claude-scripted Blender renders (Workbench, flipped-shell outline) in the same palette and outline colour.

### Outline and shadow

- **Outline:** 2 world px (4 px @2×), baked into each SVG, in ink navy. Every silhouette gets it; interior lines are 1 world px. *Fallback if cars turn to mush at 0.45×: a constant-screen-width outline shader.*
- **Light:** one light, from the top-left.
- **Shadow:** each upright or vehicle sprite has a separate shadow sprite: its silhouette in shadow colour, offset 3 world px down-right, on a shadow layer under everything upright. It does not rotate with the vehicle, so the light stays consistent through turns.
- **Interior shading:** at most one flat shade tone per colour (the side away from the light). No gradients.

### Palette

Saturated red, yellow and green are **reserved for game signals** (Lights, stop lines, Patience, Blowing the red, Jam-levels, GRIDLOCK). Orange is **reserved for the Raccoon** (its vest and Raccoon UI moments). Nothing else may use them.

| Token | Hex (starting point) | Use |
|---|---|---|
| `ink` | `#1B2340` | Outlines, UI text shadow |
| `shadow` | `#0E1424` at 45% | Shadow sprites |
| `signal_red` | `#E8322B` | Red Light, red stop line, GRIDLOCK, Heavy Jam, last Patience pip |
| `signal_yellow` | `#F5C518` | Yellow Light, Busy Jam, first Patience pips |
| `signal_green` | `#2ECC40` | Green Light, Clear Jam |
| `raccoon_orange` | `#FF7A1A` | The vest; construction stripes in UI |
| `blinker` | `#FFE3A3` | Blinkers only: pale amber, tiny, flashing |
| `brake` | `#C4242B` | Brake lights only: tiny, at the rear |
| Car bodies | blue `#3A7BD5`, sky `#5BC0EB`, purple `#8E5BD6`, pink `#F27BB5`, white `#EEF1F6`, charcoal `#4A5060` | The 6 safe body tints |
| `asphalt` | `#3B4252` | Road surface (subtle noise) |
| `pavement` | `#5E6A80` | City blocks, kerbs |
| Rooftops | cool blues, slates, muted purples | Block scatter. **No trees** (green is reserved) |
| `sign_blue` | `#1F5FAF` | UI sign panels |

Hex values are first guesses; tune them in the proof, keeping the reservation rule.

### Type and UI

- **Font: Bungee** (OFL), for all UI and the Crash burst words.
- **Panels:** blue road signs: rounded corners, white inset border, white text. One sign-panel SVG as a 9-patch (`NinePatchRect`) covers most screens.
- **Raccoon moments** (the "NEW: …" badge, the name/logo lockup) use orange-and-navy construction stripes.
- **GRIDLOCK banner** is the one full-red UI element.
- **HUD:** a slim sign strip along the top: score, Combo, the Jam meter (filled in Jam-level colours) and stage/Quota.

### Anchors and draw order

- **Anchor at the ground contact:** the Raccoon's feet, the pole's base, a vehicle's centre.
- **Layers, bottom to top:** ground and blocks → road → road decals → shadows → vehicles → upright sprites (Raccoon, poles; **Y-sorted**) → floating cues → Crash bursts → HUD.
- **Floating cues are upright and never rotate** with their vehicle.

### Scale ladder

| Sprite | Footprint (world px) | Notes |
|---|---|---|
| Lane / road | 30 / 60 | One lane each way |
| Car | 38 × 20 | |
| Motorcycle | 22 × 10 | Rider's helmet in a safe bright tint |
| Semi | 84 × 24 | Cab 24 + trailer 60, **one rigid sprite** |
| Raccoon | 28 wide; sprite ~28 × 38 | Taller than its footprint in ¾ view |
| Light pole | ~10 × 34 | Head overhangs the kerb |

## Sprite list

Canvas sizes are @2× and include the outline margin. "Tint" means a white layer tinted in Godot. Animations marked *cutout* are part motion in Godot (AnimationPlayer/tweens), not drawn frames.

### Raccoon

Cutout rig: head, body with vest, tail, 2 arms, 2 legs, drawn for **3 facings: front (moving down), back (moving up), side (mirrored for left)**. Diagonal movement shows the side view. Facing always follows the joystick.

| ID | Shows | Canvas @2× | Anchor | Notes |
|---|---|---|---|---|
| `raccoon_front_*` | Parts, front facing | ~64 × 84 overall | Feet | Mask, ringed tail, vest front with reflective stripes |
| `raccoon_back_*` | Parts, back facing | ~64 × 84 | Feet | Vest back, tail prominent |
| `raccoon_side_*` | Parts, side facing | ~64 × 84 | Feet | Mirrored in Godot for left |
| `raccoon_arm_reach` | Swap-in paw-open arm | — | Shoulder | Used by Switch |
| `rope` | Tow line | drawn in code | — | Line from paw to wreck, `ink` with a light core |
| `stars` | Stunned stars | 40 × 16 | Centre | Circle the head during Bonk |
| `dust_puff` | Dash dust | 24 × 16 | Centre | Plus 2 speed lines drawn in code |

| Animation | Motion (cutout) | Length | Loops |
|---|---|---|---|
| Idle | Breathing bob, tail sway, blink every few seconds | 1.2s | yes |
| Walk | 2-beat bob, legs swing, tail trails | 0.4s per cycle, synced to speed | yes |
| Dash | Squash, then stretch along the move direction, legs tucked; dust puff | 0.18s (the Dash) | no |
| Switch | Arm snaps up toward the pole, head tilts up, back down; the stop line changes at the peak | 0.25s | no |
| Tow | Leans forward away from the wreck, rope over the shoulder, heavy walk | Walk at 0.6× | yes |
| Bonk | Knocked along the knockback, one spin, squash flat, stars until the stun ends, pop up | the stun | no |

### Vehicles

Every vehicle is stacked layers: **body** (tint, one of the 6 safe colours), **details** (windows, roof lines, outline; never tinted), **lamps** (brake and blinker overlays, shown/hidden; blinkers flash in code), and **shadow**. Top-down, one view, rotated freely in Godot, so turns are smooth at any angle.

| ID | Shows | Canvas @2× | Anchor | Notes |
|---|---|---|---|---|
| `car_body`, `car_details`, `car_lamps_brake`, `car_lamps_blink_l/r`, `car_shadow` | Car | 84 × 48 | Centre | Nose points +X |
| `car_wreck_details` | Crumpled car | 84 × 48 | Centre | Swapped in for details; body keeps its tint |
| `moto_*` (same layers) | Motorcycle and rider | 52 × 28 | Centre | Rider's helmet tinted separately |
| `moto_wreck_details` | Bike on its side, rider sprawled | 52 × 36 | Centre | |
| `semi_*` (same layers) | Semi, cab + trailer, rigid | 176 × 56 | Centre | Trailer is the tinted body; cab details fixed |
| `semi_wreck_details` | Jack-knifed look, drawn rigid | 176 × 56 | Centre | |
| `ambulance_*` | *Stretch.* Ambulance | 88 × 48 | Centre | Light bar **blue and white**, not red |

### Floating cues (upright, never rotate)

| ID | Shows | Canvas @2× | Notes |
|---|---|---|---|
| `cue_turner` | A Turner waiting for a gap | 32 × 32 | Left-arrow icon, pulses once the Turner is stuck (#17) |
| `cue_honk` | A Honk | 40 × 32 | Burst "HONK" shape above the car |
| `cue_patience_ring` | Patience | drawn in code | Shown only after the first Honk (#17). Pips: yellow, yellow, red |
| `cue_blow` | Blowing-the-red warning | 32 × 32 | "!!" flashing for the last 3s of Patience (#14) |
| `cue_swell` | Swell tell at the road edge | 48 × 48 | Triple chevrons (#14) |

### Lights

| ID | Shows | Canvas @2× | Anchor | Notes |
|---|---|---|---|---|
| `light_pole` | Pole + 3-lamp head, ¾ view | ~20 × 68 | Base | One per approach, 4 per crossing |
| `light_lamp_red/yellow/green` | The lit lamp | overlay | — | Only the active lamp is lit |
| `stop_line` | Stop bar across the lane | decal, 4 × 30 | Centre | **Tinted the Light's colour**: the main cue at 0.45× |

### Crashes and Wreckage

| ID | Shows | Canvas @2× | Notes |
|---|---|---|---|
| `crash_burst` | Comic starburst | 160 × 120 | White, `ink` outline, upright; one word in Bungee |
| Burst words | KRUNCH!, BONK!, SKRRT-BAM!, … (~5) | text | Picked at random, never in signal colours |
| `debris_bits` | Bumper, hubcap, glass shards | 8–16 each | CPUParticles2D textures |
| `smoke_puff` | Smoke | 32 × 32 | Burst puffs, and a looping wisp on Wreckage until Towed |

Juice: a 60 ms freeze and a small camera shake per Crash. The Gridlock sequence reuses the bursts in bulk.

### Roads and ground

Roads are drawn **in code** from the crossing data (centres plus approach directions), so any angle, including the 5-way, works. SVG decals go on top.

| ID | Shows | Notes |
|---|---|---|
| Asphalt | Road surface | Code-drawn shapes, subtle noise texture |
| `decal_centre_dash` | Dashed centre line | White |
| `decal_crosswalk` | Crosswalk stripes | White |
| `decal_kerb` | Kerb edge | `pavement`, light top edge |
| `decal_manhole` | Manhole cover | Scatter |
| Blocks | Pavement shape with a kerb outline | Code-drawn |
| `roof_*` | ~5 building tops, AC units | Scatter; nothing looks taller than a car's shadow suggests |
| Weather overlay | *Stretch* | TBD |

### Flow and UI

| ID | Shows | Notes |
|---|---|---|
| `logo` | Title logo over Attract: **FENDER BANDIT**, with the tagline **"Stop. Go. Oops."** in small Bungee underneath | Construction-stripe lockup in Bungee. One flourish, such as a raccoon mask or a crumpled bumper worked into a letter. Name and tagline from #11 |
| `app_icon` | Window, web favicon and itch thumbnail | A "Raccoon Crossing" sign: an orange construction diamond with a navy raccoon silhouette and navy border. Must read at 16 px (#11) |
| `ui_sign_panel` | Blue sign 9-patch | Most screens |
| `ui_button_*` | Cabinet button glyphs for the controls card | A Switch, X Dash, Y Tow (#10, #17) |
| `ui_new_badge` | "NEW: …" on the tally card | Construction stripes |
| `ui_gridlock` | GRIDLOCK banner | Full red |
| `shatter_shards` | Glass-shatter pieces | Screen capture split into shards in code |
| HUD strip | Score, Combo, Jam meter, stage/Quota | Sign panel |
| Pause, results, initials picker, High-score table | Screens | Sign panels + Bungee |

## Deferred

- **Reference mockup** (a full stage-9 screen at base resolution): moved to the build phase as the first art ticket.
