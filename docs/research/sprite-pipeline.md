# Sprite pipeline: Blender renders, Godot import, and legibility at zoom

Research half of [#6](https://github.com/klusignolo/GameJam2026/issues/6). Researched 2026-09-30 against Blender 5.2.1 LTS (installed) and Godot 4.7 docs.
Builds on [art-audio-tools.md](https://github.com/klusignolo/GameJam2026/blob/research/art-audio-tools/docs/research/art-audio-tools.md) (#3), which chose Claude-scripted Blender for sprites. Ownership of Blender output is settled there and isn't repeated here.

"Tested" below means it ran on the dev machine (Ryzen 9 5900X, RTX 3080, Windows 11) with [`sprite-pipeline/spike.py`](sprite-pipeline/spike.py). Everything else is cited.

## TL;DR

| Question | Answer |
|---|---|
| 2:1 pixel iso camera | Orthographic, **rotation X = 60°, Z = 45°** (30° elevation). Tested: a 1×1 ground square renders as a 69×34 px diamond, i.e. 2:1. (True isometric, X = 54.736°, gives 1.73:1, not 2:1.) |
| Top-down camera | Orthographic, rotation (0, 0, 0), looking straight down −Z. Tested. |
| Fastest flat renderer | **Workbench**: 13 ms/frame at 128 px (Flat light) and ~110 ms (Studio light plus hull outline). EEVEE takes ~80 ms/frame at 4 samples after a ~250 ms shader warm-up, and showed shadow acne at low samples. |
| Outlines in 5.2 | **Inverted hull** (Solidify, flipped normals, back-face-culled black material) works in Workbench and EEVEE. Tested. Workbench's own *Outline* option draws only a thin silhouette. Freestyle and Grease Pencil Line Art both exist in 5.2, but both gave **empty strokes** in our headless spike (not debugged). |
| Transparent PNG | `render.film_transparent = True`, PNG, RGBA, view transform `Standard`. Tested. |
| N directions | Rotate a parent Empty (the turntable) by 360°/N per frame and `render.render(write_still=True)`. Tested with 8 directions. |
| Sheet packing | No ImageMagick or system Python is needed. **Blender's bundled numpy** packs frames via `Image.pixels.foreach_get/set`. Tested. Alternatively, Godot loads loose per-frame PNGs into SpriteFrames. |
| Scripted raccoon | Feasible: primitives, joined mesh, armature via `edit_bones`, keyframes on pose bones, headless. Auto-weights on joined primitives didn't visibly move the legs, so use **rigid bone-parented parts**. The limit is art direction, not the API. |
| Image-to-3D | **TripoSR (MIT)** is the only clean, free option that fits a 10–12 GB RTX 3080. TRELLIS (16 GB) and TRELLIS.2 (24 GB) are MIT but Linux-only and too big, though they have free HF demos. Hunyuan3D 2.x lets you keep outputs but excludes EU/UK/South Korea. Stable Fast 3D's free tier is capped at <$1M revenue, which is **a problem if HCSS is the user**. |
| Godot stretch | `canvas_items` + `expand` (canvas_items is the 4.7 default for new projects). The base resolution only sets the coordinate units: keep **1280×720** (the greybox numbers) and author textures at 2×. |
| Zoom-out shimmer | Yes, without mipmaps. Enable **Mipmaps > Generate** on import *and* set the texture filter to **Linear Mipmap**. Both are needed. The docs don't restrict either to Forward+, but this is untested in Compatibility. |
| Legibility | At 0.45 zoom a 38×20 car is **17×9 base px**: ~26×14 physical px on a 1080p cabinet, ~13×7 px in a 960×540 itch embed. The silhouette and a dark outline carry it. Detail won't survive. |

**The fact most likely to change the A/B/C decision:** option A's 8 pre-rendered directions give a car only **3 frames across a 90° turn** (0°, 45°, 90°), so Turners visibly snap on the quarter-circle arc. Smooth turns need 16+ directions. Top-down cars (B/C) rotate at any angle for free, with one sprite per vehicle and state. Whichever way it goes, the 0.45 zoom makes the car ~17 base px long, so extra iso detail mostly won't be seen.

## 1. Blender 5.2 headless sprite rendering

### Camera

- **2:1 pixel dimetric (option A):** ortho camera with `rotation_euler = (radians(60), 0, radians(45))`, pointed at the origin. A ground square seen at elevation *e* has height:width = sin(*e*), so 2:1 needs *e* = 30°. Tested: the 1×1 probe plane rendered as 69×34 px. The often-quoted 26.565° is the *on-screen slope* of the tile edges (atan ½), not a camera angle. True isometric (35.264° elevation) gives 1.73:1 tiles. `ortho_scale` sets how many Blender units fit the frame, so it fixes the pixels per unit. Keep it constant across every asset so the scale ladder holds.
- **Top-down (options B/C):** ortho, `rotation_euler = (0, 0, 0)`, above the model. Tested (`car_top.png`). For B's ¾-view Raccoon, use the same ortho camera tilted about 30–45° on X only, with the Raccoon facing ±X/±Y.
- **Rotate the model, not the camera.** A turntable Empty that parents the model keeps the sun fixed in world space, so light direction is consistent across directions (the spike does this).

### Renderer and look

| Engine | Tested speed (128 px) | Notes |
|---|---|---|
| Workbench, Flat light | 13 ms/frame | Solid material colours, no face shading. Too flat for iso boxes (faces merge). |
| Workbench, Studio light + hull | ~110 ms/frame | Readable face shading, clean edges, no noise. **Recommended.** |
| EEVEE (`BLENDER_EEVEE`), 4 samples | ~80 ms/frame (+~250 ms first frame) | Real sun shadows, but shadow acne on the car sides at 4 samples. Needs more samples or shadow tweaks. Toon ramps (Shader to RGB) are EEVEE-only. |

- The engine identifier is `BLENDER_EEVEE` again in 5.0. It was `BLENDER_EEVEE_NEXT` in 4.2–4.5 ([5.0 Python API notes](https://developer.blender.org/docs/release_notes/5.0/python_api/)). Older scripts and LLM memory will say `BLENDER_EEVEE_NEXT`.
- Other 5.0 breaking changes Claude-written scripts will trip on ([same page](https://developer.blender.org/docs/release_notes/5.0/python_api/)):
  - The compositor tree is `scene.compositing_node_group`, not `scene.node_tree`.
  - `ImageFormatSettings.media_type` must be set before `file_format` (the spike's plain PNG still output fine).
  - `action.fcurves`/`action.groups` are gone. Use `bpy_extras.anim_utils.action_get_channelbag_for_slot()`.
- Use view transform `Standard`, not AgX, so palette colours (especially the reserved signal red/yellow/green) come out as specified.
- Workbench *Outline* "render[s] the outline of objects in the viewport. The color of the outline can be adjusted" ([Workbench options, 5.2 manual](https://docs.blender.org/manual/en/latest/render/workbench/options.html)). In the render it's a thin, light silhouette, too faint at 0.45 zoom.
- **Outline options in 5.2:**
  - **Inverted hull** (tested, works in both engines): add a Solidify modifier (`use_flip_normals=True`, `offset=1`, small `thickness`, `material_offset` → a black material with `use_backface_culling=True`). Workbench also needs `scene.display.shading.show_backface_culling = True`. Line weight is in world units, so it scales with the model. Pick the thickness for the *final downscaled* size.
  - **Freestyle** still ships ("an edge/line-based non-photorealistic (NPR) rendering engine", [manual](https://docs.blender.org/manual/en/latest/render/freestyle/introduction.html)). `render.use_freestyle` exists in 5.2.1. In our headless spike, even with a lineset (silhouette, border and crease), it logged `Error: strokes set empty` and drew nothing. Cause not investigated.
  - **Grease Pencil Line Art** (GP v3 object, `LINEART` modifier, [manual](https://docs.blender.org/manual/en/latest/grease_pencil/modifiers/generate/line_art.html)): `bpy.ops.object.grease_pencil_add(type='LINEART_SCENE')` ran headless, but its strokes didn't appear in the render. It's heavier to set up. Not pursued.
- **Transparent output:** `scene.render.film_transparent = True`, `image_settings.file_format='PNG'`, `color_mode='RGBA'`. Tested.

### Directions, packing, timing

- **N directions:** loop `root.rotation_euler.z = i*2π/N`, set `render.filepath`, and call `bpy.ops.render.render(write_still=True)`. Animation frames: `scene.frame_set(f)` inside the same loop. Command line: `blender -b --factory-startup -P script.py -- <args>`, reading args after `--` from `sys.argv` ([command-line rendering](https://docs.blender.org/manual/en/latest/advanced/command_line/render.html)).
- **Packing without system Python or ImageMagick:** Blender's bundled Python includes numpy (tested). `pack()` in the spike loads each PNG with `bpy.data.images.load`, copies `pixels` into a numpy array (Blender rows run bottom-up), and saves a new image. Or skip sheets: Godot's SpriteFrames accepts individual textures per frame.
- **Timing:** a full run (Blender start, build, 8 Workbench iso frames, a pack, a top-down frame) takes a few seconds. The first spike, which also ran EEVEE, Freestyle and 512 px passes, took 24 s total. A whole roster (say 5 vehicles × 16 directions × 3 states + a 30-frame Raccoon × 8 directions) is minutes, not hours, in Workbench. Render time won't limit direction count. Art direction and Godot memory will.

## 2. Scripted characters and image-to-3D

### Primitive raccoon + armature by script: feasible

Tested with a scratch script (not committed):
- UV spheres (body, head, snout), a cube mask band, cone ears, and alternating-colour cylinders for a ringed tail, joined into one mesh.
- An armature built in edit mode via `arm.edit_bones.new()`.
- `parent_set(type='ARMATURE_AUTO')` ran headless and created the vertex groups.
- Keyframes via `pose_bone.keyframe_insert("rotation_euler", frame=f)`. The 5.x slotted action (`action.slots`) was created automatically.
- Rendering the 4 frames worked.

**But** automatic weights on disjoint joined primitives gave legs that barely moved. For a low-poly figure, the robust choice is **rigid parts parented to bones** (`obj.parent = rig; obj.parent_type = 'BONE'; obj.parent_bone = "FL"`). There's no skinning to go wrong, and it suits a chunky, toy-like style.

The first result read as "grey cat". Charm needs iteration: mask contrast, big ears, the tail silhouette. Budget for the art direction, not the code. Poses (Switch, Tow, Dash, bonked) are just more keyframes.

### Image-to-3D / text-to-3D (for a Gemini concept → mesh)

The dev's GPU is an RTX 3080 (10 or 12 GB). No standalone Python is installed, and every local option needs Python + CUDA PyTorch.

| Model | Licence and outputs | Territory / caps | Hardware | Free web demo |
|---|---|---|---|---|
| **TripoSR** (Stability + Tripo) | MIT, "includes the source code, pretrained models" ([repo](https://github.com/VAST-AI-Research/TripoSR)). MIT puts no claim on outputs. | None | "about 6GB VRAM". Fits the 3080. | [HF Space stabilityai/TripoSR](https://huggingface.co/spaces/stabilityai/TripoSR) |
| **TRELLIS** (Microsoft) | "models and the majority of the code are licensed under the MIT License" ([repo](https://github.com/microsoft/TRELLIS)) | None | "at least 16GB", "tested only on Linux". Won't run locally. | [HF Space Microsoft/TRELLIS](https://huggingface.co/spaces/Microsoft/TRELLIS) |
| **TRELLIS.2** | MIT ([repo](https://github.com/microsoft/TRELLIS.2)) | None | "at least 24GB", Linux only | [HF Space microsoft/TRELLIS.2](https://huggingface.co/spaces/microsoft/TRELLIS.2) |
| **Hunyuan3D 2.0 / 2.1** (Tencent) | "Tencent claims no rights in Outputs You generate" ([2.1 licence](https://github.com/Tencent-Hunyuan/Hunyuan3D-2.1/blob/main/LICENSE)). The 2.0 licence has the same clause. | "DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM AND SOUTH KOREA". Licence needed above 1M MAU. Must disclose machine-generated content. Can't use outputs to improve other AI models. | 2.0: 6 GB for shape, 16 GB with texture ([repo](https://github.com/Tencent-Hunyuan/Hunyuan3D-2)). 2.1: 10 GB for shape, 29 GB with texture. Windows is supported, and there's a community WinPortable build. | [HF Space tencent/Hunyuan3D-2](https://huggingface.co/spaces/tencent/Hunyuan3D-2). 3d.hunyuan.tencent.com has its own terms (not checked). |
| **Stable Fast 3D** (Stability) | Community Licence: "You own any outputs" ([licence](https://stability.ai/community-license-agreement)) | Free only under **$1M annual revenue**. The entity is bound if you act for it. HCSS is well over that, so if the work is for HCSS, it needs an enterprise licence. | "about 6GB VRAM". Windows is "experimental" ([repo](https://github.com/Stability-AI/stable-fast-3d)). | [HF Space stabilityai/stable-fast-3d](https://huggingface.co/spaces/stabilityai/stable-fast-3d) |

- **Free web demos run on HF ZeroGPU**, with a daily GPU quota of **2 min logged out, 5 min on a free account** ([ZeroGPU docs](https://huggingface.co/docs/hub/spaces-zerogpu)). That's enough for a few generations a day, not iteration.
- Practical fit: these output dense, triangulated meshes with baked textures. That's fine for a **static prop** (a car body to render 8/16 ways), and poor for a **rigged, animated Raccoon** (bad topology for bones, texture smeared across limbs). For the Raccoon, scripted primitives are more controllable. Image-to-3D saves time only if Gemini concepts turn out much more charming than what Claude can script.

## 3. Godot 4.7 2D

### Y-sort and anchors

- `CanvasItem.y_sort_enabled`: "this and child CanvasItem nodes with a higher Y position are rendered in front of nodes with a lower Y position… Nodes sort relative to each other only if they are on the same z_index" ([CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)). Turn it on for the one parent that holds cars, Raccoon, Lights and wrecks. Keep the road on a lower `z_index`, not Y-sorted.
- **The anchor rule follows from that:** the node origin must be the point where the sprite **touches the ground**, because Y-sort compares node positions.
  - `Sprite2D.centered` defaults to `true`, so for tall sprites (Raccoon, Light poles, iso cars) shift the texture up with `offset` (+Y is down) so the origin sits at the feet or wheel-base centre.
  - Top-down cars (B/C) are flat, so centred works and they barely need sorting. Only the Raccoon and poles overlap them.
- **TileMapLayer:** a TileSet supports square and isometric (diamond) shapes. "When using an isometric TileSet, rendering works best if all sibling TileMapLayers and their parent Node2D have Y-sort enabled" ([TileSet](https://docs.godotengine.org/en/stable/classes/class_tileset.html)). `TileData.texture_origin` offsets the tile drawing ([TileData](https://docs.godotengine.org/en/stable/classes/class_tiledata.html)).
  - Option A means an isometric TileSet (e.g. 64×32 tiles), and **every car/Raccoon position must go through the iso projection**. The greybox simulates in square world coordinates, so A adds a world→screen transform everywhere.
  - B/C keep square tiles and the greybox maths unchanged.

### Stretch, base resolution

- `canvas_items`: "everything is rendered directly at the target resolution… Recommended for most games that don't use a pixel art aesthetic… This is the default for projects created starting in Godot 4.7" (ProjectSettings `display/window/stretch/mode`, [class ref](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)). `viewport` is "recommended for games that use a pixel art aesthetic".
- Aspect: `keep` letterboxes. `expand` shows more world on wider or taller screens ([Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)). The greybox uses `keep`. With a growing world and a zooming camera, `expand` is also safe: the camera shows a little extra road.
- The docs suggest a 1920×1080 base for desktop and 1280×720 for mobile ([same page](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)). Under `canvas_items` the base only sets **coordinate units**, because output is drawn at native resolution. Crispness comes from **texture resolution**. **Keep 1280×720**, since every greybox and tuning number (38×20 cars) is in those units. Author sprites at **2×** (a 76×40 car texture on `scale = 0.5`) so a 1080p/1440p cabinet at zoom 1.0 still gets ≥1 texel per pixel.
- Avoid `viewport` + integer scale unless the look is true pixel art. Pixel art also conflicts with in-engine car rotation (B) and a 0.45–1.0 continuous zoom.

### Texture filtering and mipmaps when zoomed out

- **Downscaling without mipmaps aliases.** The docs say mipmaps "are important to smooth out pixels that are smaller than on-screen pixels" for textures "viewed at a low scale (e.g. due to Camera2D zoom or sprite scaling)" (`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`, [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)). The resolution guide adds "aliasing might appear when downsampling… you can enable mipmaps on all your 2D textures. However, enabling mipmaps will increase memory usage" ([Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)). A 2×-authored sprite at 0.45 zoom on a 720p screen is drawn at ~0.23 texel/px, well into shimmer territory as cars move.
- **Turning it on takes two steps:**
  1. Import: **Mipmaps > Generate** ("smaller versions of the texture are generated on import"). The docs advise enabling it for 2D only when the camera zooms out significantly, at about +33% memory ([Importing images](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)). Ours does.
  2. Filter: set `rendering/textures/canvas_textures/default_texture_filter` (default `1` = Linear) to **Linear Mipmap**, or set `texture_filter` on the Y-sort parent (children inherit via `TEXTURE_FILTER_PARENT_NODE`).
  
  Trilinear is the default (`use_nearest_mipmap_filter = false`). The class reference marks only the *mipmap bias* setting as Forward+/Mobile-only. The mipmap filter modes carry no such note, so they should work in Compatibility. That isn't tested yet: check it in the greybox (open question 4).
- `rendering/anti_aliasing/quality/msaa_2d`: "only supported in the Forward+ and Mobile rendering methods, not Compatibility". Edge smoothing must come from the sprites' own alpha AA, so render with Workbench AA on (`display.render_aa`).
- Import **Fix Alpha Border** "reduce[s] outline effects in bilinear-filtered textures". Keep it on for Blender renders. Compress mode **Lossless** is "the default and most common compression mode for 2D assets".
- **SVG:** import option **SVG > Scale** sets the rasterisation scale (1.0 = design size). Rasterisation happens once at import, so an SVG sprite is a normal texture at runtime and needs the same mipmaps. `DPITexture` (experimental) re-rasterises SVGs for UI scale, not Camera2D zoom ([DPITexture](https://docs.godotengine.org/en/stable/classes/class_dpitexture.html)). Don't use it for world sprites.
- **Fonts under zoom:** bitmap and non-MSDF fonts blur with Camera2D zoom ([Camera2D.zoom](https://docs.godotengine.org/en/stable/classes/class_camera2d.html)). Put the HUD on a CanvasLayer, and give in-world text (Honk "!" etc.) MSDF or make it a sprite.

### SpriteFrames from a sheet

- AnimatedSprite2D → SpriteFrames panel → **Add frames from a Sprite Sheet**, then set horizontal and vertical counts and pick cells. Alternatively, Sprite2D `hframes`/`vframes`/`frame` driven by AnimationPlayer ([2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)).
- For option A, use one animation per direction ("drive_ne", …) or one sheet row per direction with `frame = dir*cols + f`. For B, one texture per vehicle state plus `rotation`.

## 4. Legibility at zoom

The measured numbers come first. Nothing below beats them.

| | Zoom 1.0 | Zoom 0.66 (#16: legible) | Zoom 0.45 (6 crossings, unjudged) |
|---|---|---|---|
| Car in base px (1280×720) | 38×20 | 25×13 | 17×9 |
| Physical px, 1080p cabinet (×1.5) | 57×30 | 38×20 | 26×14 |
| Physical px, 960×540 itch embed (×0.75) | 29×15 | 19×10 | 13×7 |

At 13×7 px, a car is a coloured lozenge with maybe a windscreen. In iso, the same car also spends pixels on its side and roof, so its footprint reads *smaller* than top-down at equal world size. Cabinet resolution is still unknown.

Guidance from sources:
- **Zach Gage, "Building games that can be understood at a glance", GDC 2018** ([transcript](http://stfj.net/DesigningForSubwayLegibility/)): the "Three Reads" (from poster design). Decide what must be read first from far away, make that biggest and highest-contrast, and push secondary information to the second and third reads. Here, the first read is Light state and car position/heading, the second is Patience/Honk and braking, the third is car type and details.
- **Mini Motorways** (Dinosaur Polo Club) was "inspired by novelty tourist maps, with bright colours and a scale that highlights the important roads and buildings". The team says colour-blind support was "more of a challenge" than in Mini Metro, because it can't lean on simple shapes ([Game Developer](https://www.gamedeveloper.com/audio/-i-mini-motorways-i-and-the-delicate-art-of-marrying-complexity-and-minimalism)). Their concept post shows they tried an isometric version before shipping flat top-down ([Dinosaur Polo Club blog](https://dinopoloclub.com/2023/07/23/behind-the-scenes-concepting-mini-motorways/)). It states no reason. Treat that as a data point, not a rule.
- **Valve, "Illustrative Rendering in Team Fortress 2" (NPAR 2007)** ([PDF](https://steamcdn-a.akamaihd.net/apps/valve/2007/NPAR07_IllustrativeRenderingInTeamFortress2.pdf)) is the standard reference on reading characters at distance through silhouette and value contrast. (I fetched it but couldn't extract the text here, so no quote.)

Rules this implies for the sprite list (my synthesis, not sourced):
1. **Silhouette first:** car, motorcycle and semi must differ in length and width ratio, not in details.
2. **Dark outline** of about 1 px at the 0.45 display size (≈4–5 px on the 2× texture), so a car separates from any road colour.
3. **Value contrast against asphalt:** light or saturated car bodies on a mid-dark road. Keep signal red/yellow/green out of car paint.
4. **State cues as big shapes:** brake lights and blinkers become whole-rear or side glows; the Honk is a bubble larger than the car.
5. **Check the smallest case:** 0.45 zoom in a 960×540 embed, with mipmaps on.

## Recommendation per option

- **A. True 2:1 iso, 8-dir pre-rendered.**
  - *Pipeline:* proven. The camera (60°/45°), Workbench plus hull and numpy packing all work headless, and render cost is trivial.
  - *Costs:*
    - (1) Turners snap between 3 frames on a 90° arc. You need 16 directions (or accept snapping), which doubles the frames for every vehicle state.
    - (2) An iso projection layer over the greybox's square-grid simulation.
    - (3) An iso TileSet for every road layout, plus iso versions of turn-lane arrows and weather.
    - (4) More pixels spent on sides and roofs that are invisible at 0.45.
  - Choose it only if the charm pays for all that in the 14 days left.
- **B. Top-down world, cars rotated in-engine, ¾-view Raccoon.** **Recommended.**
  - Cars need 1 render (or SVG) per vehicle × state, and turn arcs are smooth for free.
  - The greybox maths is untouched, and square tiles work for all layouts.
  - The Raccoon, the only character, gets the Blender ¾ treatment (4 or 8 directions, rigid-part rig) and carries the charm. Light poles can be ¾ too.
  - Mixed projection is a common, accepted convention.
  - Blender top-down renders give cars soft studio shading and an outline that SVG can match or skip.
- **C. Pure top-down.** The cheapest option. Everything can be Claude SVG (import scale 2, mipmaps). The risk is a flat, less charming Raccoon, which matters for the "Raccoons" theme. Fall back to C only if the Blender Raccoon doesn't land within about a day.

## Open questions

1. **Cabinet resolution.** It sets the physical car size at 0.45 (26 px at 1080p, but 17 px at 720p). Still unknown from #4.
2. **Freestyle and Line Art headless:** why did both give empty strokes in 5.2.1? That only matters if the hull outline looks wrong (it doesn't bend at creases, so interior lines like the windscreen edge need a colour change instead).
3. **Direction count if A wins:** 8 (snapping turns) or 16 (smooth, double the frames)? And does #17 dropping left-turn lanes remove most diagonal frames?
4. **Is 0.45 legible in practice?** Load the 2× car render into the greybox at 0.45 with mipmaps on and without, in a 960×540 browser window. This is the deciding test for #6's pipeline proof.
5. **HCSS as licensee** of any image-to-3D tool: fine for MIT models, blocked for Stable Fast 3D's free tier. Confirm whether the dev or HCSS is "You" if SF3D is ever wanted.

## Artefacts

- [`sprite-pipeline/spike.py`](sprite-pipeline/spike.py): the tested headless script (iso and top-down camera, Workbench plus hull, transparent PNG, numpy sheet pack).
- [`sprite-pipeline/car_iso_8dir.png`](sprite-pipeline/car_iso_8dir.png): 8-direction 2:1 sheet, 128 px cells. [`sprite-pipeline/car_top.png`](sprite-pipeline/car_top.png): top-down frame. Primitive boxes only: this proves the pipeline, not the art.
