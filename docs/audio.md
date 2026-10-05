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
- **Never force `playback_type`.** Leave it at the default: Sample on the web, Stream on desktop. Forcing Sample plays nothing on desktop.
- `pitch_scale` moves **pitch and tempo together** (it's the Web Audio playback rate). A live change on a looping clip works in the browser (verified in the week-1 check below).
- **In the browser, MP3 and OGG loop at the end of the file.** Sample mode honours `loop_offset` but ignores `bpm`/`beat_count` (Godot 4.7.2 passes `loop_end = 0` for both formats). So every looping music file must **end exactly at its loop end**. MP3 can't, because the encoder pads the end, so music ships as OGG cut with ffmpeg (see **Lyria loops**). On desktop, the `bpm`/`beat_count` loop end works.
- No audio plays until the first key or button press, which is also the press that leaves Attract.

### Week-1 audio check ([#20](https://github.com/klusignolo/GameJam2026/issues/20))

Done on 2026-10-01 with a throwaway scene. It's gone now; see commit history for `game/tools/audio_check/`. The test clip was 24s at 120 BPM, generated in code, with periodic PCM, looped from 8s to 24s.

| Check | Outcome |
|---|---|
| Live `pitch_scale` glide through `MUSIC_PITCH` on a looping clip, Sample mode, in a browser | **Pass.** The tempo glides smoothly and live, with no restart. |
| Loop seam, Windows build (Stream mode) | **Pass.** It loops cleanly at 1.0 and 1.12. |
| Loop seam, browser | **MP3: fails.** It clicks every loop because the browser loops to the padded file end. **OGG cut at the loop end: inconclusive.** The dev's Bluetooth speakers clicked at random moments, even in the browser's own `<audio>` player. Recheck on wired audio when the real tracks land (#38). |

What the check found:

- **MP3 encoder pre-roll.** Every MP3 decodes with about 25 ms of silence at the start (LAME's 1105-sample delay; measured by decoding and matching against the source PCM). Godot doesn't strip it, so `loop_offset` must never be 0, or every repeat replays the silence. Any later `loop_offset` is fine.
- **The browser loop end** is described under **Web limits** above.

### Sources and pipeline

| Source | Used for | How | Kept for rebuild |
|---|---|---|---|
| **Procedural** | Every SFX, and the placeholder stinger | `game/tools/make_sfx.gd`, a headless Godot script with a fixed seed: `godot --headless --path game -s tools/make_sfx.gd`, then `godot --headless --path game --import`. It writes `game/audio/sfx/*.wav` (44.1 kHz, 16-bit mono) via `AudioStreamWAV.save_to_wav`. Each sound draws from its own RNG, seeded by the script's `SEED` and the sound's name, so a rebuild is byte-for-byte the same and changing one recipe leaves the rest alone. | The function in **Recipe** |
| **Procedural, jsfxr-style** | UI blips, Combo, Jam-level, Swell whistle, Raccoon bonk | The same script, in jsfxr's manner: square and sine blips with pitch slides. (#12 planned these in jsfxr in the browser; #37 made them in the script instead, so they rebuild headless with everything else and an agent can retune them.) A jsfxr export can still replace any of them: drop the WAV over the file and put the parameter string in **Recipe**. | The function in **Recipe** |
| **Lyria** (Gemini app, work account) | Theme, gameplay groove, stinger | Download the MP3 and convert it with ffmpeg to an OGG in `game/audio/music/`, cut to end at the loop end (below). Keep the downloaded MP3 in `audio_src/` at the repo root, outside the Godot project so it doesn't ship. | The prompt in **Recipe**, plus the loop values |

ffmpeg is installed (`winget install Gyan.FFmpeg`). Python isn't needed.

**Lyria loops:** Lyria tracks usually start with an intro and end on a fade. Pick two times, in seconds:

- **`loop_offset`:** the first bar after the intro. Never 0.
- **The loop end:** the end of the last full bar before the fade, so that the loop length is a whole number of bars.

Measure both on the MP3 as ffmpeg decodes it, then cut and convert:

```
ffmpeg -i theme.mp3 -af "atrim=end=<loop end>" -c:a libvorbis -q:a 6 theme.ogg
```

**SFX import settings:** every SFX `.wav.import` has `compress/mode=0` (PCM: the clips are tiny, and plain PCM is the safest in the browser's Sample mode) and `edit/loop_mode=1` (off), except `tow_scrape`, which has `edit/loop_mode=2` (Forward, the whole file). Keep them when a file is rebuilt.

Import the OGG with `loop` on and `loop_offset` set; leave `bpm`/`beat_count` at 0. The file now ends at the loop end, which loops correctly in both the browser and the desktop build. Record `loop_offset` and the loop end on the track's entry. The stinger doesn't loop: cut it the same way and leave `loop` off.

**Lyria prompt template:** *"Instrumental cartoon caper / heist jazz-funk, [tempo] BPM, [mood]. Walking upright bass, tight snare and hi-hat, punchy brass stabs, playful [lead]. Sneaky and mischievous, comedic, loopable, no vocals, no long fade."*

### Playback rules

- **Music:** one music player, plus one stinger player, plus a pool of SFX players, plus the Tow scrape's own looping player. All of them belong to the `Audio` autoload (`game/audio/audio.gd`). `BoardCues` turns each stage's signals into sound names; `VoicePool` books the voices; `Sfx` lists every sound with its priority and level.
- **The tempo follows the jam-level:** the groove's `pitch_scale` glides to the jam-level's step whenever the level changes. Pitch rises with tempo on purpose (cartoon panic). *Fallback if Heavy grates:* a pre-stretched Heavy MP3, crossfaded.
- **Busy board:** a capped voice pool, a cap on simultaneous Honks, and a retrigger guard per sound. When the pool is full, the oldest voice of the lowest priority is cut. Priority, highest first:
  1. Gridlock
  2. Crash
  3. Raccoon hit
  4. Blowing the red
  5. Switch, Tow and Dash (the player's own actions must always be heard)
  6. Honk
  7. Everything else

  The UI blips are "everything else": a menu never shares the board with much. A sound of the same priority never cuts another, except the player's own actions, which cut the oldest of theirs, so the newest Switch is always heard.
- **Ducking:** the music dips under each Crash and under the stinger, and sits at `DUCK_PAUSE` while paused, but never dips under Honks (they're constant). The deepest duck wins; they don't add. Done with player volume, not bus effects. `MusicMix` (`game/audio/music_mix.gd`) works out the level and the tempo glide; Audio applies them to its music player each frame.
- **Player control:** a **Music: On / Off** row in the pause menu (between Resume and Quit to title), toggled with Switch and saved best-effort in `user://` next to the High-score table. Off, the music plays on silent, so turning it back on picks it up where it is. SFX are always on, because Honks are how the player reads Patience.

## Music cues

| Screen / moment | Music |
|---|---|
| Attract, title, controls card | **Theme.** During Attract the autopilot's SFX are muted. On the web it can only start on the first press (the controls card). Audio holds music back until that press (`Audio.unlock()`), so the controls card starts it from the top. |
| Stage 1 start → every Stage → tally cards | **Gameplay groove**, continuous. It doesn't restart per Stage. On the tally card it glides back to 1.0, since the Jam resets. |
| Tally card opens | **Stage-clear stinger** over the groove, which is ducked under it |
| Pause | Groove ducked |
| Gridlock | A record-scratch cuts the groove dead on the slow-mo. Then only horns, Crashes and the glass shatter. |
| Results, initials, High-score table | **Theme** comes back in |

## Sound list

Every sound starts as *not made*. Fill in **File** and **Recipe** as each one is made.

### Music

| Sound | Use | Source | File | Recipe | Loop (loop_offset / loop end, in seconds) |
|---|---|---|---|---|---|
| `theme` | Attract, title, controls, results, initials, High-score table | Lyria (placeholder: Procedural, `_theme` in `game/tools/make_music.gd`) | `audio/music/theme.ogg` | Template, about 100 BPM, laid-back and sly, muted-trumpet lead. Placeholder: 100 BPM, a one-bar bass pickup, then 8 bars of half-time walking bass, snaps, brushed hats, a vibes lead and brass answers | 2.4 / 21.6 |
| `groove` | Every Stage and tally card; glides with the jam-level | Lyria (placeholder: Procedural, `_groove` in `game/tools/make_music.gd`) | `audio/music/groove.ogg` | Template, about 112 BPM, driving and busy, brass-section lead. Placeholder: 112 BPM, a one-bar drum-fill intro, then 8 bars of funk drums, walking bass, brass stabs and a muted-square lead | 2.142857 / 19.285714 |
| `stinger` | Stage cleared (tally card opens) | Lyria (placeholder: Procedural, `_ta_da`) | `audio/sfx/stinger.wav`, until #38's Lyria cut | A short brass "ta-da!" hit, about 2s, no loop (trim the longest clean hit) | no loop |

**The placeholder tracks** (#38) stand in for the Lyria cuts, so the music is wired and tested end to end. They're built the shape a Lyria cut will be: a one-bar intro, then an 8-bar loop the file ends on. `game/tools/make_music.sh [theme] [groove]` rebuilds them (both by default): `make_music.gd` (seeded, with `make_sfx.gd`'s building blocks) writes WAVs to `audio_src/` (gitignored), and ffmpeg encodes each to `game/audio/music/<name>.ogg`. Their imports have `loop` on and `loop_offset` at the intro's end. Every placeholder tempo has a whole number of samples per beat, so the loop is exactly 32 beats; the OGGs decode to exactly the loop end. All of them are in D minor, in the progression Dm Dm Gm Gm Dm Dm A7 A7, and anything ringing past the loop end is wrapped into the loop's start, so the seam is as it sounds when looping.

**Swapping in a Lyria track:** cut and encode it to `game/audio/music/<name>.ogg` as in **Lyria loops**, set `loop_offset` in its `.ogg.import`, and fill its row. From then on, name only the other track to `make_music.sh`, or it writes the placeholder over the cut.

### Raccoon

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `switch_green` | **Switch** Red → Green | Chunky relay clack, high | Procedural | `audio/sfx/switch_green.wav` | `_relay(1.0, 1.0)` |
| `switch_yellow` | **Switch** Green → Yellow | The same clack, pitched to the middle | Procedural | `audio/sfx/switch_yellow.wav` | `_relay(0.82, 1.0)` |
| `dash` | **Dash** | Short whoosh | Procedural | `audio/sfx/dash.wav` | `_dash` |
| `tow_grab` | **Tow** starts | Grab "clunk" | Procedural | `audio/sfx/tow_grab.wav` | `_clunk(1.0)` |
| `tow_scrape` | **Tow**, while dragging | Metal scrape, looping | Procedural | `audio/sfx/tow_scrape.wav` | `_scrape (1s loop, Forward)` |
| `raccoon_hit` | A car hits the Raccoon (no **Yield**) | Cartoon "bonk" | Procedural, jsfxr-style | `audio/sfx/raccoon_hit.wav` | `_bonk` |

### Lights and drivers

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `light_red` | A **Light** falls Yellow → Red on its own | Softer relay clack | Procedural | `audio/sfx/light_red.wav` | `_relay(0.62, 0.0)` |
| `honk_1` | First **Honk** | Short "beep", ±pitch per car | Procedural | `audio/sfx/honk_1.wav` | `_honk: one 0.2s beep` |
| `honk_2` | Second **Honk** | Long angry "beeeep-beep", the same horn | Procedural | `audio/sfx/honk_2.wav` | `_honk: 0.55s, then 0.2s` |
| `blow_red` | **Blowing the red** | Engine rev plus tyre squeal | Procedural | `audio/sfx/blow_red.wav` | `_blow_red` |
| `yield` | **Yield** | Brake squeal | Procedural | `audio/sfx/yield.wav` | `_brake_squeal` |

### Crashes

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `crash_1`, `crash_2`, `crash_3` | **Crash** (random pick, ±pitch) | Cartoon crunch plus glass tinkle | Procedural | `audio/sfx/crash_1.wav` to `crash_3.wav` | `_crash`, three draws |
| `gridlock_scratch` | **Gridlock**, slow-mo starts | Record scratch | Procedural | `audio/sfx/gridlock_scratch.wav` | `_scratch` |
| `gridlock_horns` | **Gridlock** | Chorus of held horns | Procedural | `audio/sfx/gridlock_horns.wav` | `_horns` |
| `gridlock_shatter` | **Gridlock**, the screen shatters | Big glass shatter | Procedural | `audio/sfx/gridlock_shatter.wav` | `_shatter` |

### Run and world

| Sound | Event | Sound design | Source | File | Recipe |
|---|---|---|---|---|---|
| `combo_up` | **Combo** reaches each 5× step | Rising blip | Procedural, jsfxr-style | `audio/sfx/combo_up.wav` | `_arpeggio(880, 1175, 1760 Hz)` |
| `combo_break` | **Combo** reset by a **Crash** | Deflating "wah-wah" | Procedural, jsfxr-style | `audio/sfx/combo_break.wav` | `_wah_wah` |
| `jam_busy` | **Jam-level** rises to Busy | Short warning beep | Procedural, jsfxr-style | `audio/sfx/jam_busy.wav` | `_beeps(880 Hz, 1)` |
| `jam_heavy` | **Jam-level** rises to Heavy | Double warning beep | Procedural, jsfxr-style | `audio/sfx/jam_heavy.wav` | `_beeps(1040 Hz, 2)` |
| `swell` | A **Swell** is flagged, 1s before it moves (`Traffic.swell_flagged`). The only warning: nothing shows on screen until it moves | Traffic-cop whistle toot | Procedural, jsfxr-style | `audio/sfx/swell.wav` | `_whistle` |
| `reveal` | A crossing attaches (the reveal) | Whoosh plus construction "ka-chunk" | Procedural | `audio/sfx/reveal.wav` | `_reveal` |

### UI

| Sound | Event | Source | File | Recipe |
|---|---|---|---|---|
| `ui_move` | Menu or initials cursor moves | Procedural, jsfxr-style | `audio/sfx/ui_move.wav` | `_blip(660 → 720 Hz)` |
| `ui_confirm` | Menu confirm, initials letter set | Procedural, jsfxr-style | `audio/sfx/ui_confirm.wav` | `_arpeggio(880, 1320 Hz)` |

### Deliberately silent

- **A car leaves the map:** it would be constant noise.
- **Engines and city ambience:** no per-car engine loops and no ambience bed. They cost voices in Sample mode, and positional audio is unreliable on the web. The music carries the bed.

## Deferred

- **Raccoon chitter** on `raccoon_hit`: a polish stretch goal. The dev may record one. jsfxr and Lyria can't make a believable animal sound.
