#!/usr/bin/env bash
# Shoots the sprite proof (#18) to docs/art/proof/: every sprite at on-screen zooms 1× and 0.45× in a 960×540 window,
# with and without mipmaps, plus the 0.45 floor as a 960×540 window really shows it (0.34×). Re-run it when the sprites
# change. Needs a window, so it isn't headless. Run from anywhere:
#   game/tools/sprite_proof.sh
# GODOT overrides the editor path, as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1  # refresh the class_name cache
"$GODOT" --path "$GAME" --resolution 960x540 -s tools/sprite_proof.gd
