#!/usr/bin/env bash
# The headless whole-game smoke test (#34, #35, #36): one press leaves Attract, the Attract autopilot plays the Run a few stages, then the Raccoon goes
# idle, the Run must Gridlock, and the results, Initials and High-score table must give way to Attract, which must show the table. Exits non-zero on any logged error or a missed step. Run from anywhere:
#   game/tools/smoke.sh               # a fresh seed (Main prints it)
#   game/tools/smoke.sh --seed=7      # repeat a run exactly
# GODOT overrides the editor path, as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1  # refresh the class_name cache
"$GODOT" --headless --fixed-fps 60 --path "$GAME" -s test/smoke.gd -- "$@"
