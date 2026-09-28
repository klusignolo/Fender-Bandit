# Godot 4.7 web export: engine constraints

Research for [#8](https://github.com/klusignolo/GameJam2026/issues/8). Sources checked 2026-09-27 against Godot **4.7.2-stable** (released 2026-08-18, [release post](https://godotengine.org/article/maintenance-release-godot-4-7-2/)).

This replaces only the **engine-specific** parts of [#4](https://github.com/klusignolo/GameJam2026/issues/4) ([findings](https://github.com/klusignolo/GameJam2026/blob/research/godot-web-cabinet/docs/research/godot-web-cabinet.md)), which were written for Godot 3.6. The engine-independent findings there (input design, unknown screen size, itch.io hosting, save-data caveats, organizer questions) still stand and are not repeated here, except where Godot 4 changes a name or detail.

Unless marked otherwise, quotes come from [Exporting for the Web (stable = 4.7)](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html). When a claim comes from an earlier 4.x source, the version is stated.

## TL;DR

Use the **Compatibility renderer (WebGL 2)** and the default **single-threaded** web export (Thread Support off, Extensions Support off). Write everything in **GDScript**, since C# can't export to web. For 2D, very little is lost. Audio defaults to low-latency **Sample** playback, which drops AudioEffects (bus reverb, filters, etc.). Expect roughly a 40 MB engine `.wasm` (about 10 MB gzipped), and a browser at least as new as Chrome 91 / Firefox 89 / Safari 16.4.

## 1. Renderer: Compatibility (WebGL 2.0) only

- "Godot 4 can only target WebGL 2.0 (using the Compatibility rendering method). Forward+/Mobile are not supported on the web platform [...] Godot currently does not support WebGPU."
- The [renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) says to choose Compatibility if "You are developing for web. In this case, Compatibility is the only choice." It is "Used by default on the web platform", and the 2D Games row for Forward+/Mobile reads "Yes, but Compatibility is usually good enough for 2D."
- **Set the project's renderer to Compatibility from day one**, so the editor preview matches the web build. The same renderer page says switching between Compatibility and Forward+/Mobile "may require some manual tweaks".

### What Compatibility loses that could matter for a 2D game

Source: the feature tables in the [renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) (4.7). Any feature *not* listed there "is available in all renderers".

| Feature | Compatibility | Impact on us |
|---|---|---|
| 2D rendering features | Supported | None. |
| Glow, tonemapping, adjustments | Supported | A bloom-y crash flash is possible. |
| Screen texture (`hint_screen_texture`) in shaders | Supported | Screen-shake/distortion shaders are fine. |
| Custom post-processing via a fullscreen quad | Supported | Fine. |
| 2D HDR viewport / HDR output | Not supported | Colors are RGBA8 LDR. Avoid designs that need HDR 2D. |
| MSAA 2D | Not supported | Use sprite art with filtering. There's no 2D line/polygon MSAA. |
| Particle trails, particle SDF collision | Not supported | Don't rely on trails for skid marks. Use sprites/Line2D. |
| Compute shaders, RenderingDevice access | Not supported | Not needed. |
| Adaptive/Mailbox V-Sync | Not supported | Irrelevant in a browser. |

- **Particles.** GPUParticles2D works on Compatibility, but `emit_particle()` "is only supported on the Forward+ and Mobile rendering methods, not Compatibility" ([GPUParticles2D class ref](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html)). CPUParticles2D "may perform better on low-end systems or in GPU-bottlenecked situations" ([2D particle systems](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html)). Since Godot 4.2, CPUParticles gets no new features without a GPU counterpart ([State of particles, Godot blog](https://godotengine.org/article/progress-report-state-of-particles/)). Either node is fine for small crash bursts. Prefer **CPUParticles2D** for simple bursts (no GPU shader compile, no `emit_particle()` gap), and GPUParticles2D only if a specific effect needs it.
- **2D lights and shadows.** The 4.7 [2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html) and [Light2D](https://docs.godotengine.org/en/stable/classes/class_light2d.html) pages list no Compatibility-specific restriction. The Godot 3.6 GLES2 rule "each light is a separate pass" no longer applies as a documented limit. Treat lights as a performance cost to test on the web build, not a banned feature.
- **Shaders.** Compatibility compiles GLSL ES 3.0, so the GLES2 "no dynamic loops" limit from 3.6 is gone. Documented Compatibility gaps ([shading language](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)): no `samplerCubeArray`, and sampler arrays can only be indexed by compile-time constants (use a `switch`). Always use the `source_color` hint on color uniforms.

## 2. Threads vs single-threaded

- **Single-threaded is the default and the recommended option.** "Since Godot 4.3, Godot supports exporting your game on a single thread [...] It is also more compatible overall with stores like itch.io [...] The single-threaded export works very well on macOS and iOS too, where it always had compatibility issues with multiple threads exports. For these reasons, it is the preferred and now default way to export your games on the Web."
- **Its costs:** "it cannot use threads, and is not as performant as the multi-threaded export". Do not use `Thread`/`WorkerThreadPool` in gameplay code.
- **Thread Support on** requires SharedArrayBuffer, a secure context, and `Cross-Origin-Opener-Policy: same-origin` + `Cross-Origin-Embedder-Policy: require-corp`. Without the headers or the PWA service-worker workaround, "the project will not run". On itch.io this means the opt-in SharedArrayBuffer embed setting and its `html.itch.zone` domain move (see #4 findings). There is no reason to take that on.
- **Extensions Support** (GDExtension) also needs cross-origin isolation headers, and extensions must be compiled for web. **Leave it off.**
- History (4.3, [Web Export in 4.3, Godot blog, 2024-05-15](https://godotengine.org/article/progress-report-web-export-in-4-3/)): single-threaded builds were restored in 4.3 largely because of itch.io jam games. "Apple devices (macOS and iOS) were long known to have issues [...] when you do export your game single-threaded, these issues fortunately disappear."
- **Safari:** "Safari has several issues with WebGL 2.0 support that other browsers don't have, so we recommend using a Chromium-based browser or Firefox if possible." Safari should work with the single-threaded export, but it's the browser most likely to show rendering bugs. If the cabinet turns out to be a Mac, test there.

## 3. Export size and load time

- **Measured locally from the installed 4.7.2 templates** (`web_nothreads_release.zip`): `godot.wasm` is 39,514,754 bytes (about 39.5 MB) uncompressed, and about 10.1 MB with `gzip -9`. `godot.js` is about 280 KB. Our `.pck` gets added on top. For comparison, the 4.3 blog quoted "around 40 MB uncompressed, and 5 MB compressed with Brotli" for 4.3.
- **Compression on itch.io, conflicting sources.** Godot's 4.7 doc lists itch.io under "Hosts that don't provide on-the-fly compression". itch.io's own [HTML5 docs](https://itch.io/docs/creators/html5) say its CDN "will automatically apply GZIP compression" to `html, js, css, svg, wasm, wav, glb, pck`, and honor pre-compressed `.gz`/`.br` files. itch owns that behavior, so **trust itch's docs**, but check the `content-encoding` of `godot.wasm` in the browser devtools after the first upload.
- Either way, a ~10 MB gzipped first load is fine for a jam game and far under itch's limits (see #4). Godot boots with a loading bar (the boot screen during loading was added in 4.3 per the 4.3 blog). To shrink the wasm, Godot suggests "compile an optimized export template with unused features disabled". That's optional and probably not worth the jam time.
- **VRAM Texture Compression:** only enable it if we use VRAM-compressed textures. 2D sprites normally use lossless/lossy import, so leave it at the defaults.
- **WASM SIMD (since 4.5):** "the 4.5 release official templates will only support WebAssembly SIMD-compatible browsers in order to keep the template sizes small" ([Upcoming (serious) Web performance boost, Godot blog, 2025-06-05](https://godotengine.org/article/upcoming-serious-web-performance-boost/)). It's a 1.5-2x speedup, at the cost of a browser floor (section 7).

## 4. Audio on web

- **Default is Sample playback via the Web Audio API** (since 4.3). It "allows for low latency even when the project is exported without thread support". Limitations (4.7 doc):
  - "AudioEffects are not supported."
  - "Reverberation and doppler effects are not supported."
  - "Procedural audio generation is not supported." (no AudioStreamGenerator)
  - "Positional audio may not always work correctly depending on the node's properties." (AudioStreamPlayer2D)
- Only static streams can be registered as samples: "wav, ogg vorbis, mp3" (4.3 blog).
- **Stream playback** (`Audio > General > Default Playback Type.web`, or per player) gives the full audio feature set, but with "increased latency (especially when thread support is disabled)". Don't use it for crash SFX.
- **Autoplay:** "Some browsers restrict autoplay [...] request the player to click, tap or press a key/button to enable audio." This is unchanged from 3.6. Keep the "press any button" title screen.
- **Spec consequence:** plain `AudioStreamPlayer`s playing WAV/OGG/MP3 clips. Do the mixing and ducking with bus/player volume, not AudioEffects. For variety, bake variants into the files instead of relying on bus effects. Check `pitch_scale` randomization on the web build before depending on it.

## 5. Gamepads in web builds

- Unchanged from 3.6 in substance: "Gamepads will not be detected until one of their button is pressed. Gamepads might have the wrong mapping depending on the browser/OS/gamepad combination". It requires a secure context (itch is HTTPS).
- 4.x detail ([Controllers, gamepads and joysticks](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html)): "Since Godot 4.5, the engine relies on SDL 3 for controller support on Windows, macOS, and Linux", but Godot's older custom code "is still used to support controllers on Android and Web, so it may result in issues appearing only on those platforms". Also: "Web controller support is often less reliable compared to 'native' platforms." So a **native** cabinet build would get better gamepad mapping than the web build. That's one more reason to ask the organizers (#4, Q2/Q4).
- The InputMap guidance from #4 stands: every action bound to both keyboard and joypad.

## 6. `user://` persistence, fullscreen, background tabs

Same behavior as 3.6. The API names are updated for 4.x:
- `user://` persists in IndexedDB only if cookies are allowed. In an iframe, third-party cookies must also be allowed, and incognito never persists. Check with `OS.is_userfs_persistent()`, which (new in the 4.7 doc) "can give false positives in some cases". So high scores stay best-effort, and the fallback needs to survive a silent write loss.
- Fullscreen must be entered "from within a pressed input event callback such as `_input` or `_unhandled_input`. Querying the Input singleton is not sufficient". In 4.x the call is `DisplayServer.window_set_mode(...)`. The fullscreen project setting "doesn't work unless the engine is started from within a valid input event handler". Rely on itch's fullscreen button, or toggle from `_input`.
- The tab being hidden pauses `_process`/`_physics_process`. This "does not apply to unfocused browser windows".
- Canvas: "The window size will automatically match the browser window size by default".
- Export the main file as **`index.html`**, and don't rename the other exported files: "Some issues could occur if some exported files are renamed".

## 7. Language and browser minimums

- **GDScript only.** "Projects written in C# using Godot 4 currently cannot be exported to the web [...] To use C# on web platforms, use Godot 3 instead." This is confirmed in the 4.7 doc. Also avoid GDExtension (section 2).
- **Browser floor** = WebGL 2.0 + WebAssembly with **fixed-width SIMD** (official templates since 4.5):
  - WebGL 2.0: Chrome 56, Edge 79, Firefox 51, Safari 15 (desktop and iOS) ([Can I use WebGL 2.0](https://caniuse.com/webgl2), linked from the Godot doc).
  - WASM SIMD: Chrome 91, Firefox 89, Safari 16.4 ([WebAssembly feature status](https://webassembly.org/features/), data from [features.json](https://github.com/WebAssembly/website/blob/main/features.json)).
  - **Effective minimum: Chrome/Edge 91+ (mid-2021), Firefox 89+, Safari 16.4+ (2023).** An older cabinet browser would need custom `wasm_simd=no` templates built from source. That costs jam time, so ask the organizers which browser the cabinet runs.
- Secure context (HTTPS or localhost) is needed for gamepads and other features. itch provides HTTPS. A cabinet that loads the build from `file://` is not a secure context, which makes the "native vs web on the cabinet" question more important.

## 8. What changed in 4.4 to 4.7 for web

The 4.7 release page ([Godot 4.7](https://godotengine.org/releases/4.7/)) and the 4.7.2 maintenance post list no web-platform changes that affect these constraints. The notable 4.x web milestones are: 4.3 (single-threaded export, Sample audio, PWA header helper, loading boot screen) and 4.5 (SIMD-only official templates, SDL 3 gamepads on desktop but not web). I found no 4.4/4.6 web change that alters the list below. I did not read every changelog line.

## Constraints the spec must respect (revised for Godot 4.7)

1. **Compatibility renderer (WebGL 2) from day one.** Default single-threaded web export: Thread Support off, Extensions Support off, no PWA.
2. **GDScript only.** No C#, no GDExtension, and no `Thread`/`WorkerThreadPool` in gameplay.
3. **2D effects within Compatibility:** no HDR 2D, no 2D MSAA, no particle trails, no `emit_particle()`. Prefer CPUParticles2D for crash bursts. Light2D and custom canvas shaders are allowed (loops OK, including screen-texture effects), but check their performance on the web build.
4. **Audio as Sample playback:** WAV/OGG/MP3 clips, no AudioEffects (no bus reverb/filters/doppler), no generated audio, and treat positional 2D audio as unreliable. A press-a-button title screen unlocks audio.
5. **Input (unchanged from #4):** InputMap actions bound to keyboard and joypad. Web gamepads appear only after a button press and may be mis-mapped. Web gamepad support is weaker than native (no SDL 3 on web).
6. **Screen (unchanged from #4, 4.x names):** stretch mode `canvas_items` (non-pixel-art) or `viewport` + integer scale (pixel art), aspect `expand` or `keep`, with an anchored HUD and a safe play rectangle.
7. **High scores are best-effort.** Use `user://`/IndexedDB with an `OS.is_userfs_persistent()` check that may false-positive, so the fallback must tolerate silent loss.
8. **Fullscreen only from `_input`/`_unhandled_input`,** or itch's button. The game pauses when the tab is hidden.
9. **Payload about 10 MB gzipped** (39.5 MB raw wasm) plus the pck. Export as `index.html`, and don't rename the exported files.
10. **Browser floor: Chrome/Edge 91+, Firefox 89+, Safari 16.4+,** in a secure context. Safari is the riskiest for WebGL 2 bugs.

## New question for the organizers

- If the cabinet runs the web build: which browser and version, and is the build served over HTTPS/localhost or opened from `file://`? (Godot 4.5+ templates need WASM SIMD, and gamepads need a secure context.)
