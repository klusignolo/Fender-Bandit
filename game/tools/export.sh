#!/usr/bin/env bash
# Exports the Web and Windows builds headless (#13 §8). Run from anywhere:
#   game/tools/export.sh            # release builds
#   game/tools/export.sh --debug    # debug builds
# Output: game/build/web/index.html and game/build/windows/FenderBandit.exe (gitignored).
# Needs the Godot 4.7.2 editor and its export templates. GODOT overrides the editor path.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
MODE="--export-release"
[[ "${1:-}" == "--debug" ]] && MODE="--export-debug"

rm -rf "$GAME/build/web" "$GAME/build/windows"  # never leave a stale build behind a failed export
mkdir -p "$GAME/build/web" "$GAME/build/windows"
touch "$GAME/build/.gdignore"  # keep Godot from importing its own exports
"$GODOT" --headless --path "$GAME" --import
for preset in Web Windows; do
	echo "== Exporting $preset"
	"$GODOT" --headless --path "$GAME" "$MODE" "$preset" 2>&1 | tee "$GAME/build/export-$preset.log"
	if grep -q "ERROR" "$GAME/build/export-$preset.log"; then
		echo "Export of $preset logged errors" >&2
		exit 1
	fi
done
ls -la "$GAME/build/web/index.html" "$GAME/build/windows/FenderBandit.exe"
