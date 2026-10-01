# Tuning register

Every number the game is tuned by: what it's for, its starting value, the ticket that set it, and what playtests have said. All values are **starting points, to be tuned (or cut) by feel**. When a playtest changes one, update its row and add a note; don't start a new file.

The latest greybox with all of these in it: `prototypes/turners/` on the [`prototype/crossing-guard`](https://github.com/klusignolo/GameJam2026/tree/prototype/crossing-guard/prototypes/turners) branch. Its constants use the names in the **Greybox** column.

## Stage knobs

The difficulty curves. Each is fixed for a whole Stage and steps up between Stages ([#7](https://github.com/klusignolo/GameJam2026/issues/7)). Values are linear from stage 1 to stage 9, then ease toward a far limit with no ceiling. A Debut stage holds the knobs still, so the new feature is the only thing that gets harder (but see the open question below).

| Knob | What it's for | Stage 1 → 9 → far limit | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Spawn gap | Seconds between cars on each entry. The main volume dial. | 3.2s → 1.0s → 0.6s | `K_GAP` | #7 | #17: the dev didn't get past stage 4. Tough, but "a good starting point". |
| Car speed | Multiplier on car speed. Less time to react. | 1.0× → 1.4× → 2.0× | `K_SPEED` | #7 | |
| Patience | Seconds a front driver waits at red before running out (three Honk stages). Paces the Honks; from stage 7 it's the Blowing-the-red timer. | 15s → 12s → 7s | `K_PATIENCE` | #7, #14 | |
| Turner share | Share of drivers who turn left (Turners) and may hold up their lane. It breaks the plain N/S ↔ E/W rhythm. Zero before stage 3. | 10% at stage 3 → 20% at stage 9 → 25% | `K_TURNERS` | #17 | #17: 15% → 30% felt like too many. The dev wants it to "stay lower". |
| Ease past 9 | How fast knobs close in on their far limit after stage 9 (the share of the gap left each stage). | 0.85 | `K_EASE` | #7 | Expert Runs should become impossible somewhere around stages 15–20. |

**Open question: Debuts hold the knobs, but the Opening is almost all Debuts.** Stages 3, 4, 5, 7, 8 and 9 are Debuts, so "Debuts hold the knobs still" and "the knobs reach their stage-9 values by stage 9" can't both be true. For now, a Debut stage uses the previous stage's values, and the next stage jumps to its own values. Decide this in the build or in a later tuning pass.

## Stage length and Quota

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Target stage length | How long a stage should last if traffic flows. The Quota is derived from it. | 45s at stage 1 → 75s at stage 9, then flat | `TARGET_LEN` | #7 | Stage 6 comes out at a Quota of about 210 with two crossings. Check whether that drags. |
| Quota | Cars that must leave the map to clear the stage. | target length ÷ spawn gap × entry roads | `_quota()` | #7, #15 | #16 counted cars leaving the map. |
| Drain phase | After the Quota: spawning stops and traffic drains, up to this long. | 12s | `DRAIN_MAX` | #16 | |

## Traffic shape

Uneven from stage 1, so a fixed light cycle starves a road ([#14](https://github.com/klusignolo/GameJam2026/issues/14)). The Swell is the only shape left; its strength and shift time could become stage knobs if difficulty needs more levers.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Swell strength | The heavy road's spawn rate compared with the others. | 2× heavy, 0.67× the rest | `SWELL_HEAVY`, `SWELL_LIGHT` | #14 | "Helps break the rhythm." #17: the dev likes the triple-chevron tell ("intuitive that traffic will be heavier in that lane"). |
| Swell shift | How long a road stays heavy, and the warning before the next one. | 20–30s, 4s warning | `SWELL_MIN/MAX`, `SHIFT_WARN` | #14 | |
| ~~Platoon~~ | **Cut in #17.** It was a tight bunch of 4–6 cars leaving one entry every 8–14s. | n/a | n/a | #14 | #17: "heavy and platoon FEEL like they do the same thing." The Swell stays. |

## Turners

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Turner gap | Seconds of clear oncoming road a Turner wants before it goes. Higher values mean longer holds. | 1.4–2.0s, drawn per driver | `GAP_MIN/MAX` | #17 | Holds of about 1–4s on green in headless runs. |
| Turn speed | Speed through the turn, as a share of normal speed. | 0.7× | `TURN_SPEED` | #9 | |

## Right turns

Right turns happen everywhere, for natural-looking traffic ([#13](https://github.com/klusignolo/GameJam2026/issues/13)). They aren't a difficulty lever: a right-turning car obeys its Light (no turning on red), never waits for a gap, never holds up its lane, and signals with its right blinker. Where geometry leaves no straight exit (the T, some 5-way approaches), the route picker chooses among the movements the approach actually has.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Right-turn share | Share of drivers who turn right. It's drawn separately from the Turner share; everyone else goes straight. Flat from stage 1, with no Debut. | 15% | not built | #13 | |

## The Jam

One meter for the whole city ([#15](https://github.com/klusignolo/GameJam2026/issues/15)). Its fill must scale with map size ([#16](https://github.com/klusignolo/GameJam2026/issues/16)).

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Fill from waiting | Per second, for each front driver (or Turner) that has Honked. | 0.5/s after one Honk, 1.0/s after two | `JAM_HONK` | #15 | |
| Fill from backlog | Per second, for each car that can't get onto the map. | 0.6/s | `JAM_BACKLOG` | #15 | |
| Drain | Per second, always. **Scales with crossings** so a bigger map doesn't fill the Jam faster. | 1.5/s per crossing | `JAM_DRAIN` | #15, #16 | #16: with a flat 1.5/s, the Jam filled far too fast once the second crossing attached. Scaling by crossings was first tried in #17. |
| Drain per exit | A bonus for each car that leaves the map. | 0.4 | `JAM_EXIT` | #16 | |
| Dent | Jam capacity lost for good per Crash. | 2% | `DENT` | #15 | Kept small: Wreckage is the real punishment. |
| Jam-levels | Where Busy and Heavy start, as a share of the capacity not lost to Dents. | Busy 40%, Heavy 70% | `_level()` | #15 | #17: the Heavy pulse adds to the noise when every crossing is backed up. |

## Vehicle sizes

Footprints in world px. They're gameplay, not just art: a longer vehicle blocks the box for longer. The look is in [`docs/sprites.md`](sprites.md).

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Car | The standard vehicle. | 38 × 20 | `CAR_L`, `CAR_W` | #5 | Legible at ~0.66 zoom (#16). |
| Motorcycle | Small and fast; harder to see. | 22 × 10 | not built | #6 | First guess. |
| Semi | Long and slow; one rigid sprite, so its turn arc cuts the corner. | 84 × 24 | not built | #6 | First guess. |
| Raccoon | The player: kept at car scale so the hero reads. | 28 wide (sprite ~28 × 38) | `RACCOON_R` | #5, #6 | |

## Raccoon

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Move speed | On-screen speed, constant at any zoom. | 230 px/s | `RACCOON_SPEED` | #15 | #16: travel between crossings felt like a chore, partly because Dash went unused. |
| Dash | Burst speed, how long it lasts and its cooldown. | 640 px/s for 0.18s, 0.9s cooldown | `DASH_*` | #5 | #16: Space was added as Dash. |
| Targeting range | How close a Light must be to Switch it (on screen). | 160 px | `SIGNAL_RANGE` | #9 | |
| Yellow | How long a Light stays Yellow before falling to Red. | 1.5s | `YELLOW_TIME` | #5 | |

## Presentation tied to tuning

| Setting | Value | Set by | Notes |
|---|---|---|---|
| Patience ring | Hidden until the driver's first Honk | #17 | A ring on every front car at red was noise by stage 4. |
| Blowing-the-red warning | The car flashes "!!" for its last 3s of Patience | #14 | `BLOW_WARN` |
| Reveal | 2.5s pull-back when a crossing attaches | #16 | `REVEAL_TIME` |
