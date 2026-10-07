#!/usr/bin/env bash
# Renders the itch.io art: the cover (#42) to docs/art/itch-thumbnail.png, 630x500, and the page banner to
# docs/art/itch-banner.png, 960x240, both from the Raccoon Crossing diamond and the name lockup. Re-run it when
# icon.svg or the lockup changes. Needs a window, so it isn't headless. Run from anywhere:
#   game/tools/make_thumbnail.sh
# GODOT overrides the editor path, as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1  # refresh the class_name cache
"$GODOT" --path "$GAME" --resolution 630x500 -s tools/make_thumbnail.gd
"$GODOT" --path "$GAME" --resolution 960x240 -s tools/make_thumbnail.gd -- --banner
