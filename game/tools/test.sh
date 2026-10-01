#!/usr/bin/env bash
# Runs every headless test (#13 §10). Exits non-zero if any fails. Run from anywhere:
#   game/tools/test.sh                    # all tests
#   game/tools/test.sh --only=yellow      # tests whose file:name contains "yellow"
# GODOT overrides the editor path, as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1  # refresh the class_name cache
"$GODOT" --headless --path "$GAME" -s test/run.gd -- "$@"
