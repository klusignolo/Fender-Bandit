# Publishing to itch.io

The game ships as two channels on one itch project, pushed with [butler](https://itch.io/docs/butler/):
`html5` (the in-browser build, `game/build/web`) and `windows` (`game/build/windows`).
`game/tools/publish.sh` does a whole update: tests, smoke test, release export, both pushes.
The itch project defaults to `kittypounce/fender-bandit`; set `ITCH_TARGET=<user>/<slug>` if yours differs
(or change the default in the script).

**Status (2026-10-06):** https://kittypounce.itch.io/fender-bandit is **Public** and submitted to the jam, so every
push reaches players at once; rehearse with `--dry-run` when unsure. The deadline is Oct 14, 2026, 11:59 PM Central;
after it, push only what the jam rules allow (usually bug fixes).

## One-time setup (done)

1. **Install butler.** Download https://broth.itch.zone/butler/windows-amd64/LATEST/archive/default
   (a zip). There's no installer: put `butler.exe` and its two DLLs directly in `~/.local/bin` (already on PATH),
   not in a subfolder, and check `butler -V`.
2. **Log in.** `butler login` opens the browser once and saves a key to `~/.config/itch/butler_creds`.
3. **Create the project** at https://itch.io/game/new:
   - Title **Fender Bandit**, URL slug `fender-bandit` (must match `ITCH_TARGET`).
   - Kind of project: **HTML**. Classification: Game.
   - Leave Visibility on **Draft** for now and save. No uploads yet; butler makes them.
4. **First push.** `game/tools/publish.sh` (commit or `--allow-dirty` first).
5. **Finish the page** (Edit game):
   - Uploads: tick **"This file will be played in the browser"** on the `html5` upload. The `windows` upload
     gets the Windows tag from its channel name.
   - Embed options: viewport **1280 × 720**, tick **Fullscreen button**. Leave
     "SharedArrayBuffer support" off (the Web preset exports without threads).
   - Cover image: `docs/art/itch-thumbnail.png` (630×500). Screenshots: `docs/art/stage9-reference.png` or fresh `--shot=` captures.
   - Description: tagline "Stop. Go. Oops.", the pitch, and the controls (WASD/arrows + buttons; no mouse).
   - Save, open the page, play a run in the browser and launch the Windows zip.
6. **Go public and submit.** Set Visibility to **Public** (or Restricted while testing), then on
   https://itch.io/jam/2026-hcss-game-jam click **Submit your project** and pick Fender Bandit.
   Deadline: **Oct 14, 2026, 11:59 PM Central**.

## Updating

```bash
game/tools/publish.sh             # the usual update
game/tools/publish.sh --dry-run   # rehearse: checks + export, no upload
```

butler uploads only the diff, and the page picks up the new build within a minute or two
(`butler status kittypounce/fender-bandit` shows when it's live). The pushed version is `git describe`
of HEAD, so every build traces to a commit. After the jam deadline, push only what the jam rules allow.
