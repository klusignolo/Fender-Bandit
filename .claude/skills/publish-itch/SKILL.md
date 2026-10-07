---
name: publish-itch
description: Publish or update Fender Bandit on itch.io (butler push of the Web and Windows builds). Use when the user says "publish", "ship it", "push to itch", "update the itch page", or "release a build".
---

# Publish to itch.io

The process and one-time setup live in `docs/publishing.md`; the script is `game/tools/publish.sh`. Read the doc
if anything below fails.

1. **Preflight.**
   - `butler -V` works and `butler login` has been done (the script checks both). If not, stop and give the user
     the setup steps from `docs/publishing.md`; `butler login` is interactive, so suggest they run `! butler login`.
   - `git status`: the script refuses a dirty tree. Other sessions may be mid-change in this repo, so never commit,
     stash, or discard someone else's work to get a clean tree. Ask the user whether to wait, or publish the dirty
     tree with `--allow-dirty` (only if they say so).
   - Confirm with the user before the real push: the page is public and submitted to the jam, so a push reaches
     players at once. After the deadline (Oct 14, 2026, 11:59 PM Central), also ask whether the jam rules allow it. Say which commit (`git describe --always --dirty`)
     will go up. A `--dry-run` needs no confirmation.
2. **Publish.** From the repo root in Git Bash: `game/tools/publish.sh` (it runs the tests, the smoke test, the
   release export, then `butler push` to the `html5` and `windows` channels). It takes a few minutes; run it in
   the background if needed. If the tests or smoke test fail, stop and report; don't reach for `--skip-checks`
   unless the user asks.
3. **Report.** Relay the version pushed, then poll `butler status kittypounce/fender-bandit` (in a background until-loop) until both channels show a build; channels stay missing for a few minutes after a first push. Each build should show a √.
   Remind the user of the hands-on check: open the itch page, play a run in the browser.
