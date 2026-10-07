#!/usr/bin/env bash
# Publishes the Web and Windows builds to itch.io with butler (docs/publishing.md). Run from anywhere:
#   game/tools/publish.sh                 # test, smoke, export release builds, push both channels
#   game/tools/publish.sh --dry-run       # everything but the upload
#   game/tools/publish.sh --skip-checks   # skip the tests and the smoke test
#   game/tools/publish.sh --allow-dirty   # publish uncommitted changes (the version gets a -dirty suffix)
# ITCH_TARGET overrides the itch project (user/game). BUTLER overrides the butler path. GODOT works as in export.sh.
set -euo pipefail
GAME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$GAME/.." && pwd)"
TARGET="${ITCH_TARGET:-kittypounce/fender-bandit}"
BUTLER="${BUTLER:-butler}"
DRY="" CHECKS=1 DIRTY=0
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY="--dry-run" ;;
		--skip-checks) CHECKS=0 ;;
		--allow-dirty) DIRTY=1 ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

command -v "$BUTLER" >/dev/null || { echo "butler not found: install it (docs/publishing.md) or set BUTLER" >&2; exit 1; }
if [[ -z "${BUTLER_API_KEY:-}" && ! -f "$HOME/.config/itch/butler_creds" && ! -f "$APPDATA/itch/butler_creds" ]]; then
	echo "butler isn't logged in: run 'butler login' once" >&2
	exit 1
fi
if [[ $DIRTY == 0 && -n "$(git -C "$REPO" status --porcelain)" ]]; then
	echo "The working tree has uncommitted changes; commit them or pass --allow-dirty" >&2
	git -C "$REPO" status --short >&2
	exit 1
fi
VERSION="$(git -C "$REPO" describe --always --dirty)"

if [[ $CHECKS == 1 ]]; then
	"$GAME/tools/test.sh"
	"$GAME/tools/smoke.sh"
fi
"$GAME/tools/export.sh"

echo "== Pushing $VERSION to $TARGET ${DRY:+(dry run)}"
"$BUTLER" push "$GAME/build/web" "$TARGET:html5" --userversion "$VERSION" $DRY
"$BUTLER" push "$GAME/build/windows" "$TARGET:windows" --userversion "$VERSION" $DRY
echo "Pushed. itch processes builds for a few minutes; check with: butler status $TARGET"
