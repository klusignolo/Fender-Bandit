# Art and audio tools: what's free, and can the output become HCSS IP?

Research for [#3](https://github.com/klusignolo/GameJam2026/issues/3). Researched 2026-09-27.
Budget: $0 (the only exception is a paid tool the dev would keep using heavily after the jam).

## TL;DR

| Asset | Recommended pipeline | Fallback |
|---|---|---|
| Car sprites (8-dir, 3/4 iso) | Claude writes a **Blender Python** script: low-poly car models, fixed orthographic isometric camera, rotate 45° × 8, render transparent PNGs, then pack into a sheet | Top-down: one Claude SVG per car, rotated in-engine |
| Raccoon character | Same Blender pipeline (low-poly raccoon, 8 directions, a few pose frames) | Claude SVG raccoon parts animated in Godot (cutout); Gemini concept art as reference only |
| UI, HUD, icons, title | Claude-written **SVG** (Godot 3.6 imports SVG as a texture at import time) plus a free OFL font | Gemini image for a title-card background (see watermark caveat) |
| SFX | **jsfxr / sfxr.me** for arcade blips, whistles, horns; Claude-written procedural audio (Python writing WAV) for crashes and engine loops; export WAV | Gemini/Lyria is music-only, not SFX |
| Music | **Gemini app (Lyria 3 Pro)** on the work account, *if HCSS okays it*; download MP3, convert to OGG | **BeepBox** (beepbox.co), composed by the dev, export WAV to OGG |

Ownership verdict: every candidate either assigns output to the user (Anthropic), disclaims ownership (Google), or is a tool whose license says nothing about output because the output is simply the user's own work (Blender, jsfxr, BeepBox). None of them blocks assigning the game's assets to HCSS. The real caveats are (1) **pure-AI output may not be copyrightable at all** in the US, so what HCSS "gets" is whatever rights exist, and (2) for the work Gemini account, the **customer is HCSS** (the Workspace tenant), which is favourable, but the dev must confirm HCSS's internal AI-use policy allows it for a jam entry.

## Jam rules

The jam page (https://itch.io/jam/2026-hcss-game-jam) as fetched carries no text on IP, AI, or third-party assets; the "games and assets become HCSS IP" rule is from the dev's brief (CLAUDE.md). `/rules` returns 404. **Open question:** get the actual IP/AI wording from the organisers.

## Copyright baseline (US)

The US Copyright Office's *Copyright and Artificial Intelligence, Part 2: Copyrightability* (released 2025-01-29, https://www.copyright.gov/ai/, report PDF: https://www.copyright.gov/ai/Copyright-and-Artificial-Intelligence-Part-2-Copyrightability-Report.pdf) concludes that generative-AI output is protected only where a human author has determined sufficient expressive elements, for example human-authored work perceptible in the output, or creative selection, arrangement, or modification by a human. Prompts alone are not enough. (Summary per the Office's bulletin: https://content.govdelivery.com/accounts/USLOCCOPYRIGHT/bulletins/3d0f30f.)

Implication: assets the dev *authors* (a Blender model Claude scripted but the dev directed and tweaked, a BeepBox song the dev composed, hand-arranged sprite sheets) are on firmer ground than raw prompt-to-image or prompt-to-music output. Raw Gemini images/Lyria tracks can still be *assigned* to HCSS contractually, but there may be little or no copyright to assign. For a jam this is a curiosity, not a blocker.

## Tool by tool

### Claude (dev's subscription): SVG, Blender Python, procedural audio code

- **Can produce:** text/code only. SVG vector art, Blender `bpy` scripts that build and render models, Python/GDScript that synthesises WAV audio, GDScript shaders. No native raster image or audio generation.
- **Consistency:** excellent. The camera, lighting, scale and palette are code, so all 8 directions and all cars match by construction. That is the big win for 8-direction sprites, which image generators are bad at.
- **Ownership:** Consumer Terms: "Subject to your compliance with our Terms, we assign to you all of our right, title, and interest—if any—in Outputs." (https://www.anthropic.com/legal/consumer-terms). Commercial Terms: Customer "owns its Outputs", and Anthropic "hereby assigns to Customer its right, title and interest (if any) in and to Outputs" (https://www.anthropic.com/legal/commercial-terms). The dev can therefore pass these on to HCSS. Restrictions are about using outputs to build competing AI models, which don't apply here.
- The *rendered* PNGs/WAVs come from Blender or the dev's own script run locally, not from Claude, which strengthens the human-authorship story.

### Blender (free, GPL)

- **Ownership:** "What you create with Blender is your sole property. All your artwork – images or movie files – including the .blend files and other data files Blender can write, is free for you to use as you like." (https://www.blender.org/about/license/). No restriction on assigning to HCSS.
- **Pipeline sketch:** orthographic camera at the isometric angle (e.g. ~30° elevation, 45° azimuth); model on a turntable empty rotated in 45° steps; transparent film; low sample count or Workbench/EEVEE flat shading for a clean pixel-friendly look; render at 2× and downscale; pack frames with a script or Godot's `AnimatedSprite` frames. Everything runs headless (`blender -b -P script.py`), so Claude can write and iterate the script.
- **Risk:** Blender/3D know-how on the dev's side and time spent tuning the look. Mitigate by spiking one car early.

### Work Gemini account (Google Workspace, likely HCSS's tenant)

- **Which terms apply:** for Workspace editions where the Gemini app is a core service, use is governed by the Google Workspace agreement; for "additional service" users it's the consumer Google Terms of Service (https://support.google.com/gemini/answer/14620100?hl=en&co=DASHER._Family%3DBusiness-Enterprise). The Gemini app is a core service for Business Starter/Standard/Plus, Enterprise Starter/Standard/Plus, Frontline and others, "covered under your existing Google Workspace ... agreement" (https://workspaceupdates.googleblog.com/2024/10/gemini-app-enterprise-data-protection-core-service-expansion.html).
- **Ownership (Workspace terms):** "As between Customer and Google, Google does not assert any ownership rights in any new intellectual property created in the Generated Output." Generated output can't be used to build competing models or reverse engineer Google. Google also offers an IP indemnity for unmodified Generated Output, with exceptions (https://workspace.google.com/terms/service-terms/). Note the **Customer is the employer's organisation**, so output made on a work account arguably belongs to the employer from the start. If the employer is HCSS, that aligns with the jam rule.
- **Ownership (consumer terms, if the tenant uses "additional service"):** "Google won't claim ownership over that content" (https://policies.google.com/terms). The Gemini API terms say the same and add "Google may generate the same or similar content for others" (https://ai.google.dev/gemini-api/terms).
- **Images (Nano Banana / Imagen):** work accounts get image generation, from up to 20/day at basic tiers to up to 1000/day at the top tier (14620100 page above). All Gemini-app media carries an invisible **SynthID** watermark (https://support.google.com/gemini/answer/16722517). Google's Nano Banana Pro post says the visible "Gemini sparkle" stays on free and AI Pro images and is removed only for AI Ultra and AI Studio (https://blog.google/innovation-and-ai/products/nano-banana-pro/). The watermark-settings help page says the visible-watermark toggle depends on plan (https://support.google.com/gemini/answer/17405358). I could not find an official statement on whether a *Workspace* account's images carry the visible sparkle. **Check by generating one image.** Consistency: poor for 8 matching directions of the same car. Use for concept art, palette, or a title background only. The images are also opaque (no true alpha), so sprites need manual cut-out.
- **Music (Lyria 3 Pro):** available to Business Starter/Standard/Plus, Enterprise Starter/Standard/Plus and more, users 18+, tracks up to 3 minutes, controlled by the admin's Generative AI settings (https://workspaceupdates.googleblog.com/2026/04/expanding-access-to-longer-musical-tracks-in-the-Gemini-app.html). Short (~1 min) or full (~2-3 min) tracks, download as MP3 (or MP4 with cover art), "Each generated track will have an embedded digital watermark" (https://support.google.com/gemini/answer/16901237). Work-account daily limits range from about 10 to 100 tracks/day by tier (14620100). Godot 3.6 imports MP3 but recommends Ogg Vorbis for music (https://docs.godotengine.org/en/3.6/tutorials/assets_pipeline/importing_audio_samples.html). A SynthID audio watermark is inaudible and harmless for a jam.
- **Policy risk:** the terms allow it, but **the employer's acceptable-use policy decides** whether a work account may be used for a personal jam entry. Because the jam is HCSS's and the output becomes HCSS IP, this is probably fine, but ask.

### sfxr family (jsfxr at https://sfxr.me, Bfxr at https://www.bfxr.net)

- Free, browser-based retro SFX generators. jsfxr is released under the **Unlicense** (public domain) (https://github.com/chr15m/jsfxr). Neither site states terms on generated sounds. There is no service agreement that claims them, so they are the dev's own work. Assignable.
- Good for whistles, blips, horns, UI sounds and cartoony crash crunches. Export WAV, which Godot recommends for short, repeated SFX.

### BeepBox (https://beepbox.co)

- Free browser chiptune tracker, MIT-licensed code (https://github.com/johnnesky/beepbox). There are no terms on songs because the song is the user's composition, which is the strongest ownership position of all the music options. Export WAV, convert to OGG.
- Cost: the dev (or Claude, by writing note data) must actually compose. Fine for a looping 60-90 s arcade tune.

### Procedural audio via Claude-written code

- Claude writes a Python (numpy/wave) or GDScript `AudioStreamGenerator` script for engine hums, skids, and layered crash noises. Deterministic, tweakable, fully owned (Anthropic assignment plus the dev's own execution). Good complement to sfxr for the "big crash" payoff.

## Excluded or not recommended

- Paid generators (ElevenLabs SFX, Suno/Udio paid tiers, Midjourney) break the $0 budget and add their own licence terms. Not researched in depth because nothing here suggests the dev would keep paying for them after the jam.
- Free asset packs (Kenney etc.) are CC0 and would be assignable, but they conflict with the "all assets AI-produced, dev-directed" premise in CLAUDE.md.

## Open questions for the dev

1. **HCSS work-account policy:** is the dev allowed to use the company Gemini (Workspace) account for the jam? Is the Gemini app a core service on that tenant (Workspace terms) or an additional service (consumer terms)? Is Lyria/music enabled by the admin?
2. **Jam rules text:** get the organisers' actual wording on IP assignment and AI-generated assets. It wasn't on the public page.
3. **Visible watermark:** generate one test image on the work account to see whether the Gemini sparkle appears. If it does, Gemini images are reference-only.
4. **Blender comfort:** spike one car (8 directions) before committing to isometric. If it takes more than about half a day, fall back to top-down SVG.
