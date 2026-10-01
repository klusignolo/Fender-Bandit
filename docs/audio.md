# Audio register

How the game sounds: the fixed rules every sound follows (the **style sheet**) and one entry per sound (the **sound list**). AI tools take this file as context, so every asset comes out consistent with the others. Decided in [#12](https://github.com/klusignolo/GameJam2026/issues/12).

Like `docs/sprites.md`, this is a living register. When a sound is made or changed, fill in its **Recipe** so it can be rebuilt, and add a note. Mix levels and the voice-pool, limit and ducking numbers are gameplay tuning and live in [`docs/tuning.md`](tuning.md#audio).

## Style sheet

### Style: cartoon caper

- **Music:** jazzy-funk "heist" music: walking bass, brass stabs, snare and a playful lead. It should feel like a raccoon getting up to mischief, and like panic once it speeds up.
- **SFX:** exaggerated real sounds. Horns, squeals and relays sound real, and Crashes are cartoon crunches with glass tinkle. UI moments are clean jsfxr arcade blips.
- **Avoid:** chiptune music, realistic city ambience, anything grim.

### Web limits (from [#8](https://github.com/klusignolo/GameJam2026/issues/8))

- In the web build, audio plays in Sample mode: WAV/MP3/OGG clips, **no AudioEffects** (no bus reverb, filters or pitch shift), no generated audio, and positional audio is unreliable. Bake every variation into the files or do it with `pitch_scale` and volume.
- `pitch_scale` moves **pitch and tempo together** (it's the Web Audio playback rate). *To verify in the week-1 smoke export:* a live `pitch_scale` change on a looping MP3 in a browser. See **Week-1 audio check** below.
- No audio plays until the first key or button press, which is also the press that leaves Attract.

### Week-1 audio check ([#20](https://github.com/klusignolo/GameJam2026/issues/20))

A throwaway scene in `game/tools/audio_check/` answers both open questions in a real browser. To run it, export (`game/tools/export.sh`), serve (`node game/tools/serve_web.mjs`), open http://localhost:8060 and press Tow (L) on the title.

- **The clip:** `loop_check.mp3`, 120 BPM, 16 beats (8s): a pad, a kick on every beat and an eighth-note lead. Its PCM loops perfectly, so any click or gap at the seam comes from the MP3. It's made by `make_loop_check.mjs` (Node, `@breezystack/lamejs`, 160 kbps mono), and looped by import settings (`loop`, `bpm` 120, `beat_count` 16), the same way the Lyria tracks will be. The decoded MP3 is 8.046s, about 46 ms longer than the loop. Some of that is probably encoder delay at the *start* of the file, so a click at the seam may come from the clip, not from MP3 looping. If it clicks, try a small `loop_offset` (about 0.025s) before blaming MP3. Also note whether the browser honours the `beat_count` loop point at all: a double kick or a 46 ms stutter means it loops the whole buffer.
- **The check:** the player forces Sample playback. Switch glides `pitch_scale` through the `MUSIC_PITCH` steps over `MUSIC_GLIDE`, and Dash snaps it back to 1.0.
- **Automated so far:** in headless Chrome the web build boots on WebGL 2, single-threaded, and `pitch_scale` glides live with no errors. Whether it *sounds* right needs ears.

| Check | Outcome |
|---|---|
| Live `pitch_scale` change on a looping MP3, Sample mode, in a browser | *Pending: the dev listens.* |
| MP3 loop seam has no click or gap (at 1.0 and 1.12) | *Pending: the dev listens.* |

Once both outcomes are recorded here, delete `game/tools/audio_check/` and the Tow hook that opens it in `game/main/main.gd`.

### Sources and pipeline

| Source | Used for | How | Kept for rebuild |
|---|---|---|---|
| **Procedural** | Most SFX | `game/tools/make_sfx.gd`, a headless Godot script with a fixed seed: `godot --headless --path game -s tools/make_sfx.gd`. It writes `game/audio/sfx/*.wav` via `AudioStreamWAV.save_to_wav`. | The function name in **Recipe** |
| **jsfxr** (sfxr.me) | UI blips, Combo, Jam-level, Swell whistle, Raccoon bonk | Make it in the browser, export WAV to `game/audio/sfx/`. | The jsfxr parameter string in **Recipe** |
| **Lyria** (Gemini app, work account) | Theme, gameplay groove, stinger | Download the MP3 and keep it as MP3 in `game/audio/music/`. Set the loop in Godot's import dock (below). | The prompt in **Recipe** |

No Python or ffmpeg is needed. If an MP3 loop seam clicks in a browser, install ffmpeg (`winget install ffmpeg`) and convert that track to OGG. Same import settings.

**Lyria loops:** Lyria tracks usually start with an intro and end on a fade. In the import dock, turn on `loop`, set `bpm`, and set `beat_count` so the loop ends on the last full bar before the fade. Set `loop_offset` to the first bar after the intro, so repeats skip it. Record all four values on the track's entry.

**Lyria prompt template:** *"Instrumental cartoon caper / heist jazz-funk, [tempo] BPM, [mood]. Walking upright bass, tight snare and hi-hat, punchy brass stabs, playful [lead]. Sneaky and mischievous, comedic, loopable, no vocals, no long fade."*

### Playback rules

- **Music:** one music player, plus one stinger player, plus a pool of SFX players. All of them belong to the `Audio` autoload.
- **The tempo follows the jam-level:** the groove's `pitch_scale` glides to the jam-level's step whenever the level changes. Pitch rises with tempo on purpose (cartoon panic). *Fallback if Heavy grates:* a pre-stretched Heavy MP3, crossfaded.
- **Busy board:** a capped voice pool, a cap on simultaneous Honks, and a retrigger guard per sound. When the pool is full, the oldest voice of the lowest priority is cut. Priority, highest first:
  1. Gridlock
  2. Crash
  3. Raccoon hit
  4. Blowing the red
  5. Switch, Tow and Dash (the player's own actions must always be heard)
  6. Honk
  7. Everything else
- **Ducking:** the music dips under each Crash and under the stinger, but never under Honks (they're constant). Done with player volume, not bus effects.
- **Player control:** a **Music: On / Off** row in the pause menu (between Resume and Quit to title), toggled with Switch and saved best-effort in `user://` next to the High-score table. SFX are always on, because Honks are how the player reads Patience.

## Music cues

| Screen / moment | Music |
|---|---|
| Attract, title, controls card | **Theme.** During Attract the autopilot's SFX are muted. On the web it can only start on the first press (the controls card). |
| Stage 1 start → every Stage → tally cards | **Gameplay groove**, continuous. It doesn't restart per Stage. On the tally card it glides back to 1.0, since the Jam resets. |
| Tally card opens | **Stage-clear stinger** over the groove, which is ducked under it |
| Pause | Groove ducked |
| Gridlock | A record-scratch cuts the groove dead on the slow-mo. Then only horns, Crashes and the glass shatter. |
| Results, initials, High-score table | **Theme** comes back in |

## Sound list

Every sound starts as *not made*. Fill in **File** and **Recipe** as each one is made.

### Music

| Sound | Use | Source | File | Recipe | Loop (bpm / beat_count / loop_offset) |
|---|---|---|---|---|---|
| `theme` | Attract, title, controls, results, initials, High-score table | Lyria | | Template, about 100 BPM, laid-back and sly, muted-trumpet lead | |
| `groove` | Every Stage and tally card; glides with the jam-level | Lyria | | Template, about 112 BPM, driving and busy, brass-section lead | |
| `stinger` | Stage cleared (tally card opens) | Lyria | | A short brass "ta-da!" hit, about 2s, no loop (trim the longest clean hit) | no loop |

### Raccoon

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `switch_green` | **Switch** Red → Green | Chunky relay clack, high | Procedural | | |
| `switch_yellow` | **Switch** Green → Yellow | The same clack, pitched to the middle | Procedural | | |
| `dash` | **Dash** | Short whoosh | Procedural | | |
| `tow_grab` | **Tow** starts | Grab "clunk" | Procedural | | |
| `tow_scrape` | **Tow**, while dragging | Metal scrape, looping | Procedural | | |
| `raccoon_hit` | A car hits the Raccoon (no **Yield**) | Cartoon "bonk" | jsfxr | | |

### Lights and drivers

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `light_red` | A **Light** falls Yellow → Red on its own | Softer relay clack | Procedural | | |
| `honk_1` | First **Honk** | Short "beep", ±pitch per car | Procedural | | |
| `honk_2` | Second **Honk** | Long angry "beeeep-beep", the same horn | Procedural | | |
| `blow_red` | **Blowing the red** | Engine rev plus tyre squeal | Procedural | | |
| `yield` | **Yield** | Brake squeal | Procedural | | |

### Crashes

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `crash_1`, `crash_2`, `crash_3` | **Crash** (random pick, ±pitch) | Cartoon crunch plus glass tinkle | Procedural | | |
| `gridlock_scratch` | **Gridlock**, slow-mo starts | Record scratch | Procedural | | |
| `gridlock_horns` | **Gridlock** | Chorus of held horns | Procedural | | |
| `gridlock_shatter` | **Gridlock**, the screen shatters | Big glass shatter | Procedural | | |

### Run and world

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `combo_up` | **Combo** reaches each 5× step | Rising blip | jsfxr | | |
| `combo_break` | **Combo** reset by a **Crash** | Deflating "wah-wah" | jsfxr | | |
| `jam_busy` | **Jam-level** rises to Busy | Short warning beep | jsfxr | | |
| `jam_heavy` | **Jam-level** rises to Heavy | Double warning beep | jsfxr | | |
| `swell` | A **Swell** is flagged | Traffic-cop whistle toot | jsfxr | | |
| `reveal` | A crossing attaches (the reveal) | Whoosh plus construction "ka-chunk" | Procedural | | |

### UI

| Sound | Event | Source | File | Recipe |
|---|---|---|---|---|
| `ui_move` | Menu or initials cursor moves | jsfxr | | |
| `ui_confirm` | Menu confirm, initials letter set | jsfxr | | |

### Deliberately silent

- **A car leaves the map:** it would be constant noise.
- **Engines and city ambience:** no per-car engine loops and no ambience bed. They cost voices in Sample mode, and positional audio is unreliable on the web. The music carries the bed.

## Deferred

- **Raccoon chitter** on `raccoon_hit`: a polish stretch goal. The dev may record one. jsfxr and Lyria can't make a believable animal sound.
