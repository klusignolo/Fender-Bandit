#!/usr/bin/env bash
# Shoots the stage-9 art reference (#39): the real game, seeded, at the real camera zoom. Every art pass is judged
# against it (docs/sprites.md "Reference"). Run from anywhere:
#   game/tools/reference_shot.sh            # writes docs/art/stage9-reference.png, 1280x720
#   game/tools/reference_shot.sh <dir>      # writes it to <dir> instead, e.g. to compare with the committed one
# The scene: stage 9 from seed 1; at 1s the north-south Lights at all three crossings go green (Lights 0, 1, 4, 5 and
# 8), so traffic flows north-south while the east-west roads queue up, Honk, Blow the red and Crash. At 31.4s the
# fourth Crash's burst is fresh, with the Wreckage of the first three still on the map.
# Needs a window, so it isn't headless; a window can't outgrow the screen, so there's no larger shot.
# GODOT overrides the editor path, as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
OUT="${1:-$GAME/../docs/art}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
SCENE=(--seed=1 --stage=9 --switch=1:0,1,4,5,8 --at=31.4)

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1
"$GODOT" --path "$GAME" --resolution 1280x720 -- "${SCENE[@]}" --shot="$OUT/stage9-reference.png"
