#!/usr/bin/env bash
# Rebuilds the placeholder Theme and groove (#38): tools/make_music.gd writes WAVs to audio_src/ (outside the Godot
# project), and ffmpeg encodes each to game/audio/music/<name>.ogg, ending where the WAV ends: the loop end. Their
# .ogg.import keep loop on and loop_offset at the intro's length (docs/audio.md, the sound list's "Music"). Run from anywhere:
#   game/tools/make_music.sh [theme] [groove]   # default: both. Leave out a track the dev has swapped for a Lyria cut.
# GODOT overrides the editor path, as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"

"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1  # refresh the class_name cache
"$GODOT" --headless --path "$GAME" -s tools/make_music.gd -- "$@"
mkdir -p "$GAME/audio/music"
NAMES=("$@")
[ ${#NAMES[@]} -gt 0 ] || NAMES=(theme groove)
command -v ffmpeg >/dev/null || { echo "ffmpeg isn't installed: winget install Gyan.FFmpeg" >&2; exit 1; }
for name in "${NAMES[@]}"; do
	ffmpeg -loglevel error -y -i "$GAME/../audio_src/$name.wav" -c:a libvorbis -q:a 6 "$GAME/audio/music/$name.ogg"
done
"$GODOT" --headless --path "$GAME" --import >/dev/null 2>&1
