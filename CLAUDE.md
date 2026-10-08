# Game Jam 2026

## Purpose

Solo entry for the 2026 HCSS Game Jam (https://itch.io/jam/2026-hcss-game-jam).
Submission deadline: Oct 14, 2026, 11:59 PM Central. Engine: Godot 3.6+ (required); we use the latest Godot (4.7.x) with GDScript.
Submitted games and assets become HCSS IP.

Themes: "Raccoons" and "Accidents happen!". Title: **Fender Bandit** ("Stop. Go. Oops."). Concept: a raccoon, controlled
directly by the player, directs traffic. Players try to route traffic safely,
and crashes are the comedic payoff.

Controls must work on an arcade cabinet (joystick + ~6 buttons) and in-browser
keyboard (WASD/arrows). No mouse required.

All art, audio, and code are produced with AI tooling, directed by the developer.
Details (mechanics, repo layout) are intentionally unsettled. Refine them in
future sessions.

## Godot development

Both MCP servers are configured in `.mcp.json`.

- **Docs: Context7.** Look up Godot 4.7 / GDScript APIs through the Context7 MCP (`resolve-library-id`, then `get-library-docs`) before writing engine code. Don't rely on memory: Godot 3 and 4 APIs differ a lot.
- **Run and debug: godot-mcp** (Coding-Solo, `@coding-solo/godot-mcp`). Use it to launch the editor, run a project and read its debug output. It needs Node.js. `GODOT_PATH` defaults to the winget install of Godot 4.7.2; set the env var to override it.

### Project commands

The Godot project lives in `game/`. Run these from the repo root in Git Bash:

- **Export both builds:** `game/tools/export.sh` (add `--debug` for debug builds). It writes `game/build/web/index.html` and `game/build/windows/FenderBandit.exe`; `game/build/` is gitignored.
- **Serve the web build:** `node game/tools/serve_web.mjs`, then open http://localhost:8060. Stop it by its PID, never by killing every `node.exe` (godot-mcp runs on Node too).
- **Run the tests:** `game/tools/test.sh` (add `--only=<part of file:test name>` to filter). It runs every `game/test/test_*.gd` headless and exits non-zero on any failure or logged error.
- **Run the smoke test:** `game/tools/smoke.sh` (add `--seed=N` to repeat a run). It boots the whole game headless into Attract and walks the arcade loop with one pad press: the controls card closes by itself, the Attract autopilot plays the Run to stage 3 (pausing once), then the Raccoon goes idle, the Run must Gridlock, the results and Initials must give way to the High-score table (saving "RAC" into a scratch table), and Attract must turn to the table. It exits non-zero on any logged error or if a step doesn't come. It takes about 6s.
- **Dev playtest keys** (keyboard, in a Run, release builds too): F8 toggles double speed, F9 meets the stage's Quota. Either keeps the Run off the High-score table.
- **Watch the autopilot:** `<godot console exe> --path game -- --autopilot` (any agent flag but `--seed` skips Attract and the controls card).
- **Screenshot a run:** `<godot console exe> --path game -- --seed=1 --shot=<png> --at=<sim seconds>`. A seed makes the run repeat exactly. It needs a window, so don't pass `--headless`.
- **Art reference shot:** `game/tools/reference_shot.sh` re-shoots `docs/art/stage9-reference.png`, the stage-9 frame every art pass is judged against (`docs/sprites.md` "Reference"). `--switch=S:L,M` switches Lights at S seconds, to stage a scene.
- **Sprite proof:** `game/tools/sprite_proof.sh` re-shoots `docs/art/proof/` (#18): every sprite at 1× and 0.45× in a 960×540 window, with and without mipmaps, plus 3× crops (`docs/sprites.md` "Proof"). It needs a window.
- **Itch cover and banner:** `game/tools/make_thumbnail.sh` re-renders `docs/art/itch-thumbnail.png` (630×500) and `docs/art/itch-banner.png` (960×240) from `game/icon.svg` and the name lockup. It needs a window.
- **Headless boot check of the exe:** `game/build/windows/FenderBandit.exe --quit-after 90 --log-file <file>`. Exported Windows builds go exclusive fullscreen.
- **Publish to itch.io:** `game/tools/publish.sh` (add `--dry-run` to rehearse it). It runs the tests and the smoke test, exports release builds and pushes them with butler to the `html5` and `windows` channels. The `publish-itch` skill wraps it; one-time setup is in `docs/publishing.md`.

## Build mode (phase 1)

Until every phase-1 issue (the sub-issues of #19) is closed, each session takes one issue from start to finish
without stopping for the dev:

- **Don't ask design questions.** Think each one through, take your own recommendation, and record the decision and
  why in the issue's closing comment (and in `docs/tuning.md` for knobs). Ask only about a true blocker.
- **Workflow:** test-first. Run `/code-review` on the diff, then fix the findings you judge worth fixing. Commit,
  push, and close the issue with architecture notes, without waiting for the dev's OK.
- **Defer the hands-on checks.** Put a "Hands-on checks" list in each closing comment, and an acceptance item
  that needs the dev (e.g. "the dev approves the city plan") goes there too. The dev runs them all after phase 1.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for klusignolo/Fender-Bandit, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
