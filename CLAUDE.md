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
- **Screenshot a run:** `<godot console exe> --path game -- --seed=1 --shot=<png> --at=<sim seconds>`. A seed makes the run repeat exactly. It needs a window, so don't pass `--headless`.
- **Headless boot check of the exe:** `game/build/windows/FenderBandit.exe --quit-after 90 --log-file <file>`. Exported Windows builds go exclusive fullscreen.

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues for klusignolo/GameJam2026, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
