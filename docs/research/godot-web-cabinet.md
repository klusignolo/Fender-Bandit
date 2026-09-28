# Platform limits: Godot 3.6 web export, itch.io, and the HCSS cabinet

Research for [#4](https://github.com/klusignolo/GameJam2026/issues/4). Sources checked 2026-09-27.

## TL;DR

Build for **GLES2 (WebGL 1.0), Regular export type (no threads)**, keyboard-first input through InputMap actions, a title screen that needs a keypress before audio or fullscreen, and a stretch mode that tolerates an unknown aspect ratio. Nothing public describes the cabinet. Every cabinet fact below is an open question for the organizers.

## 1. The jam page

Source: https://itch.io/jam/2026-hcss-game-jam (raw HTML fetched 2026-09-27).

What it says:

- Submissions open 2026-09-16 05:00:00 to 2026-10-15 04:59:59 (itch.io shows UTC; that is 11:59:59 PM CDT on Oct 14).
- "Deadline: October 14th, 2026", "Voting: October 15th - October 30th", "Winner announcement: November 4th".
- The theme is hidden in the public text ("The theme for this year is.... !!!").
- It links one external document: a Google Doc (`https://docs.google.com/document/d/18ybUD_ftQtglO4KQB4gGAJm10RnwIM-6Th070f9xDLs/...`). It **requires a Google sign-in** (the export returned a login wall), so it is presumably HCSS-internal. Any rules about engine, IP, and the cabinet probably live there. I could not read it.
- The community tab has no topics.

What it does **not** say: engine or version requirements, the cabinet, controls, resolution, whether a web or native build is wanted, file size, or judging criteria. (The Godot 3.6 requirement, themes, and IP terms in `CLAUDE.md` must therefore come from the internal doc. Nothing public confirms them.)

Prior HCSS jams ([2024](https://itch.io/jam/hcss-game-jam-2024), [2025](https://itch.io/jam/hcss-game-jam-2025)) also publish no cabinet details. The 2025 page lists 4 entries, all browser-playable. That is a weak hint that web builds are the norm.

## 2. Godot 3.6 web export

Primary source: [Exporting for the Web (3.6)](https://docs.godotengine.org/en/3.6/tutorials/export/exporting_for_web.html) unless noted.

| Topic | Fact | Consequence for us |
|---|---|---|
| Renderer | "WebGL 1.0 (GLES2) is the recommended option if you want your project to be supported on all browsers with the best performance". GLES3 = WebGL 2.0, which Safari/iOS lacks. | Use **GLES2**. |
| GLES2 feature loss | No GPU `Particles2D` (use `CPUParticles2D`), no HDR, and each light is a separate pass ("performance scales poorly with several lights"). Some shader built-ins are missing. Source: [GLES2 vs GLES3 differences](https://docs.godotengine.org/en/3.6/tutorials/rendering/gles2_gles3_differences.html). | Crash effects: CPUParticles2D and sprites. Avoid Light2D-heavy looks. |
| Shaders | GLES2/WebGL 1.0 "doesn't support dynamic loops". | Keep shaders simple. |
| Export type | Regular: "most compatible across browsers, will not support threads, nor GDNative". Threads needs SharedArrayBuffer. GDNative is bigger and slower. | Use **Regular**. No threads, no GDNative. C# supports only Regular anyway. |
| Threads on itch | itch.io can serve COOP/COEP headers via an opt-in "SharedArrayBuffer support" embed checkbox. Safari needs a popup window, and third-party iframes break ([itch.io admin post](https://itch.io/t/2025776/experimental-sharedarraybuffer-support)). | Another reason to avoid threads. |
| Audio | "Chrome restricts how websites may play audio. It may be necessary for the player to click or tap or press a key to enable audio." | Show a "press any button" title screen before music starts. |
| Fullscreen | Browsers only allow fullscreen "as a response to a JavaScript input event", so it has to be called from `_input()`/`_unhandled_input()`, not by polling `Input`. | Toggle fullscreen from an input callback, or rely on itch's fullscreen button. |
| Gamepads | "Gamepads will not be detected until one of their button is pressed" and "might have the wrong mapping depending on the browser/OS/gamepad combination". Needs a secure context (itch is HTTPS). [Controllers doc](https://docs.godotengine.org/en/3.6/tutorials/inputs/controllers_gamepads_joysticks.html): HTML5 controller support "is often less reliable" and varies by browser. | Use a keyboard-first design. If gamepad support is added, don't hard-code button indices, and test in the cabinet's actual browser. |
| Saving (high scores) | `user://` persists in IndexedDB only if cookies are allowed. In an iframe, **third-party** cookies must be enabled. Incognito never persists. Check with `OS.is_userfs_persistent()`. | High scores may silently fail to persist. Use a graceful fallback (session-only table). |
| itch domain change | Turning on itch's SharedArrayBuffer mode moves the game to `html.itch.zone`, and old local saves become unreachable ([itch post](https://itch.io/t/2025776/experimental-sharedarraybuffer-support)). | Don't toggle that setting after launch. |
| Background tab | "The project will be paused by the browser when the tab is no longer the active tab". `_process`/`_physics_process` stop. | Harmless for a single-player arcade game. Maybe auto-pause on focus loss. |
| Canvas | The default `canvasResizePolicy` is `2`: the canvas fills the whole browser window ([HTML5 shell class ref](https://docs.godotengine.org/en/3.6/tutorials/platform/html5_shell_classref.html)). | Combined with the stretch settings, this handles any embed size. |
| Boot splash | The default HTML page does not display the boot splash. | Cosmetic only. |
| Serving | `.wasm`/`.pck` compress well with gzip. itch gzips html/js/css/wasm automatically ([itch HTML5 docs](https://itch.io/docs/creators/html5)). | No action needed. |
| Networking | Only HTTP/WebSocket client/WebRTC. | Irrelevant, since there is no online play. |

Resolution handling ([Multiple resolutions](https://docs.godotengine.org/en/3.6/tutorials/rendering/multiple_resolutions.html)): for non-pixel-art, the docs recommend stretch mode `2d` with aspect `expand` to "support multiple aspect ratios". For pixel art they recommend `viewport` with `keep` or `expand`. The cabinet's aspect is unknown, so pick `expand` (or `keep` with letterboxing) and keep the play area inside a safe rectangle.

## 3. itch.io HTML5 hosting

Source: [itch.io HTML5 docs](https://itch.io/docs/creators/html5), [Creator FAQ](https://itch.io/docs/creators/faq).

- Upload a ZIP with `index.html` at its root. Limits: at most 1,000 files, 500 MB extracted in total, 200 MB per file, and 240 characters per path. The server is **case-sensitive**.
- A Godot 3.6 GLES2 build (a few MB of wasm plus the pck) is far below these limits.
- Embed modes: "Embed in page" (you set the viewport dimensions) or "Click to launch in fullscreen". There is an optional auto-generated fullscreen button. "Mobile friendly" forces click-to-launch-fullscreen on phones.
- "Click to Play" is on by default. That click also satisfies the browser's audio-unlock rule, but only for the page. Godot may still need an in-game keypress.
- Creator FAQ: "Individual file size is limited, and you should have 10 files max per page. The limit can be raised by request." (No number is published there. Forum posts cite 1 GB, which is irrelevant at our size.)

## 4. The HCSS cabinet: unknown

No public source describes it. Don't design around guesses. Keep things flexible:

- Route all input through InputMap actions and bind **both** keyboard keys and joypad buttons/axes to each action. Most arcade kits use either a keyboard encoder (shows up as keys) or a USB "zero-delay" encoder (shows up as a gamepad). This covers both without knowing which one the cabinet has.
- Treat the joystick as **digital, 8-way** (arcade sticks are microswitch-based), and keep the joypad deadzone at the default 0.2 or higher.
- Use at most ~4 gameplay buttons, plus Start/Coin-style buttons for menus. Never require a mouse, text entry, or Esc/F-keys the cabinet may not have.
- Layout-independent UI: the aspect and orientation (a vertical monitor is common on cabinets) are unknown.

## Constraints the spec must respect

1. GLES2 renderer, Regular web export (no threads, no GDNative).
2. No GPU particles: use CPUParticles2D. Use few or no Light2Ds. Keep shaders simple, with no dynamic loops.
3. A title/attract screen that needs a button press before audio (and before any fullscreen request, which must come from `_input`).
4. All controls via InputMap actions, each bound to keyboard (WASD + arrows + a few keys) **and** joypad. The stick is digital 8-way. Use ≤ 6 buttons, no mouse, no text entry.
5. The game must work at unknown resolutions and aspect ratios: stretch `2d`/`viewport` + aspect `expand` or `keep`, with the HUD anchored.
6. High-score persistence is best-effort: `user://` → IndexedDB may be unavailable (blocked third-party cookies, incognito). Check `OS.is_userfs_persistent()` and degrade gracefully. Don't flip itch's SharedArrayBuffer setting after release.
7. itch ZIP: `index.html` at the root, case-exact paths, ≤ 1,000 files. Size is a non-issue.
8. The game pauses when the tab is hidden. Design for that (auto-pause).

## Open questions for the organizers

1. Can you share the linked rules Google Doc publicly, or confirm its contents (engine/version requirement, IP terms, submission rules)?
2. Does the cabinet run the **web build** (in which browser, kiosk mode?) or a **native export** (Windows/Linux)? Should we upload both?
3. What are the screen resolution, aspect ratio, and orientation (horizontal or vertical)?
4. How do the controls show up to the OS: a keyboard encoder (which keys? a MAME-style default?) or a USB gamepad encoder? Is a mapping document available?
5. How many buttons are there per player, and in what physical layout? Are there Start/Coin/Exit buttons, and what do they send?
6. Is the stick 4-way or 8-way? Are there 1 or 2 player stations?
7. How is a game launched and exited on the cabinet (a frontend? an expected quit button?), and does it need an attract mode or idle-timeout reset?
8. Do high scores need to persist on the cabinet between sessions? Is `user://` storage kept on that machine?
9. How are games judged (on the cabinet, on itch in-browser, or both)? What are the judging criteria?
10. Are there size, performance, or content constraints (e.g., audio volume, flashing/epilepsy guidance)?
