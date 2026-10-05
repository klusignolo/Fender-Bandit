# Tuning register

Every number the game is tuned by: what it's for, its starting value, the ticket that set it, and what playtests have said. All values are **starting points, to be tuned (or cut) by feel**. When a playtest changes one, update its row and add a note; don't start a new file.

The latest greybox with all of these in it: `prototypes/turners/` on the [`prototype/crossing-guard`](https://github.com/klusignolo/GameJam2026/tree/prototype/crossing-guard/prototypes/turners) branch. Its constants use the names in the **Greybox** column. The game keeps every number here in `game/tuning.gd` (`Tuning`) under the same names. Where the greybox used an unnamed number, the ticket that ported it named it, and the Greybox column says "inline".

## Stage knobs

The difficulty curves. Each is fixed for a whole Stage and steps up between Stages ([#7](https://github.com/klusignolo/GameJam2026/issues/7)). Values are linear from stage 1 to stage 9, then ease toward a far limit with no ceiling. A Debut stage holds the knobs still, so the new feature is the only thing that gets harder (but see the open question below).

| Knob | What it's for | Stage 1 → 9 → far limit | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Spawn gap | Seconds between cars on each entry. The main volume dial. | 3.2s → 1.0s → 0.6s | `K_GAP` | #7 | #17: the dev didn't get past stage 4. Tough, but "a good starting point". |
| Car speed | Multiplier on car speed. Less time to react. | 1.0× → 1.4× → 2.0× | `K_SPEED` | #7 | |
| Patience | Seconds a front driver waits at red before it's out of Patience (three stages). Paces the Honks; from stage 7 it also sets when the driver Blows the red. | 15s → 12s → 7s | `K_PATIENCE` | #7, #14, #25 | |
| Turner share | Share of drivers who turn left (Turners) and may hold up their lane. It breaks the plain N/S ↔ E/W rhythm. Zero before stage 3. | 10% at stage 3 → 20% at stage 9 → 25% | `K_TURNERS` | #17, #24 | #17: 15% → 30% felt like too many. The dev wants it to "stay lower". |
| Ease past 9 | How fast knobs close in on their far limit after stage 9 (the share of the gap left each stage). | 0.85 | `K_EASE` | #7 | Expert Runs should become impossible somewhere around stages 15–20. |

**Open question: Debuts hold the knobs, but the Opening is almost all Debuts.** Stages 3, 4, 5, 7, 8 and 9 are Debuts, so "Debuts hold the knobs still" and "the knobs reach their stage-9 values by stage 9" can't both be true. For now, a Debut stage uses the previous stage's values, and the next stage jumps to its own values. #29 built this interim answer: a Debut stage (3, 4, 5, 7, 8 and 9, counting the crossings at 4 and 9) takes stage n-1's values, so stage 9 plays at stage 8's and stage 10 jumps to its eased value. The feature a stage debuts starts at its own first value, so stage 3 has a 10% Turner share, not stage 2's zero. Revisit in a tuning pass.

## Stage length and Quota

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Target stage length | How long a stage should last if traffic flows. The Quota is derived from it. | 45s at stage 1 → 75s at stage 9, then flat | `TARGET_LEN` | #7 | Stage 6 comes out at a Quota of about 210 with two crossings. Check whether that drags. Since #31 the Quota counts the real entries (6 with two crossings, 10 with six), so late stages run high: stage 21 is 1142. |
| Quota | Cars that must leave the map to clear the stage. Counts the entry roads the map really has: 4 with one crossing, 6 with two (#31), 7 at stage 9 (the T has no south road, #32). | target length ÷ spawn gap × entry roads, rounded | `_quota()` (inline in `Traffic._init` since #29) | #7, #15, #29 | #16 counted cars leaving the map. |
| Drain phase | After the Quota: spawning stops and traffic drains, up to this long. The backlog is dropped, and the Jam is held: it neither fills nor drains, and can't Gridlock. Crashes still Dent it and break the Combo. It ends once no car is moving (Wreckage stays). | 12s | `DRAIN_MAX` | #16, #29 | |
| Tally card | Seconds the Tally card shows over the frozen board before the next stage. | 3s | `TALLY_TIME` (new in #29) | #29 | |
| Tally lock | A (Switch) skips the Tally card only after it has shown this long, so a Switch mashed during the drain doesn't skip it. | 0.5s | `TALLY_LOCK` (new in #29) | #29 | |

## The arcade loop

The flow around a Run ([#35](https://github.com/klusignolo/GameJam2026/issues/35), [#36](https://github.com/klusignolo/GameJam2026/issues/36)): Attract → controls card → Run → Gridlock → results → Initials (top 10 only) → High-score table → Attract. Every screen moves on by itself, so the cabinet always returns to Attract (#19 story 12). Attract is the autopilot on stage 1 with a fresh seed, no HUD and a Quota it never meets, so it never leaves stage 1 and never records a score. A press of any key or pad button but Select and the guide leaves it. A (Switch) skips a card only after its lock, so a mashed press can't skip it too.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Attract length | Seconds an Attract plays before a fresh one starts on a new seed. A Gridlock starts one sooner. | 60s | `ATTRACT_TIME` | #35 | |
| Controls card | Seconds the controls card shows before the Run starts, and the lock before A closes it (the press that left Attract mustn't). | 6s, lock 0.5s | `CONTROLS_TIME`, `CONTROLS_LOCK` | #35 | |
| Gridlock hold | Seconds from Gridlock to the results, with every input ignored (#19 story 55). A plain GRIDLOCK banner for now; it's the slot the death beat (#43) fills. | 2s | `GRIDLOCK_HOLD` | #35 | #43 sets it to the beat's length. |
| Results card | Seconds the results show before Initials (or the table, for a Run outside the top 10), and the lock before A skips them. | 10s, lock 1.5s | `RESULTS_TIME`, `RESULTS_LOCK` | #35, #36 | |
| Attract pages | Seconds Attract shows its title, then the High-score table, and round again (#19 story 3: "every ~10s"). A fresh Attract starts on the title. | 6s title, 4s table: the table every 10s | `ATTRACT_TITLE`, `ATTRACT_TABLE` | #36 | |
| Initials | Seconds to enter initials before they save as "RAC" (story 15). Partly entered initials are dropped too: a player who walked away left no name. The lock before A enters a letter, so A mashed through the results doesn't enter "AAA". | 30s, lock 0.75s | `INITIALS_TIME`, `INITIALS_LOCK` | #36 | |
| Letter repeat | Holding up or down steps the letter once, then repeats after the delay, then every this often: about 2.5s to sweep the whole alphabet. | 0.4s, then every 0.1s | `REPEAT_DELAY`, `REPEAT_EVERY` | #36 | |
| High-score table | Seconds the table shows after a Run, the new entry flashing, before Attract; and the lock before A skips it. | 8s, lock 1s | `SCORES_TIME`, `SCORES_LOCK` | #36 | |

## The generator, past stage 9

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Feature floor | The fewest features a generated stage turns on, drawn from those the Opening unlocked. The count is drawn from the floor up to all of them. | 2 at stage 10, +1 every 4 stages (3 at 14, 4 at 18), all five from 22 | `FLOOR_START`, `FLOOR_EVERY` (new in #29) | #29 | Story 65 said "2, 3, then all"; the dev chose a step every 4 stages, in step with the crossings. |
| Crossing growth | A crossing attaches every this many stages after stage 9, up to a cap. Scheduled in #29; built as 4-ways in #31, with the T (stage 9) and 5-way (stage 17) from #32. | every 4 (13, 17, 21), up to 6 | `CROSSING_EVERY`, `CROSSINGS_MAX` (new in #29) | #29, #31 | |

The Opening's schedule (which stage debuts what, and the crossings at 4 and 9) is design content, not a knob: it lives in `Stages.DEBUTS` and `Stages.GROWS`, with the Opening ending at `Stages.OPENING` (9). So is the City plan (#31): where each crossing attaches, its kind and its links, in `City`. Six crossings on a 3×2 grid, every neighbour linked; at each crossing a car is a fresh driver and rolls its movement again, so it can circle a block. Past the Opening, a generated stage may turn off a feature stage 9 had on (Turners or Blowing the red at stage 10, say). Not T-junctions and 5-ways, though: they're part of the City plan, so the T and the 5-way are built whether or not the generator draws that feature (#32). Drawing it or not only counts toward the feature floor. The dev chose that variety over "never fewer features"; the knobs still step up, so difficulty doesn't drop overall.

## Traffic shape

Uneven from stage 1, so a fixed light cycle starves a road ([#14](https://github.com/klusignolo/GameJam2026/issues/14)). The Swell is the only shape left; its strength and shift time could become stage knobs if difficulty needs more levers.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Swell strength | The heavy road's spawn rate compared with the others. | 2× heavy, 0.67× the rest | `SWELL_HEAVY`, `SWELL_LIGHT` | #14, #27 | "Helps break the rhythm." #17: the dev likes the triple-chevron tell ("intuitive that traffic will be heavier in that lane"). |
| Swell shift | How long a road stays heavy, and the warning before the next one. | 20–30s, 1s warning | `SWELL_MIN/MAX`, `SHIFT_WARN` | #14, #27, dev playtest after #28 | The warning was 4s with blinking chevrons. The dev cut it to 1s, heard only (the `swell` whistle): a nudge to react, not time to prepare. It also tells you a Swell is happening somewhere. |
| ~~Platoon~~ | **Cut in #17.** It was a tight bunch of 4–6 cars leaving one entry every 8–14s. | n/a | n/a | #14 | #17: "heavy and platoon FEEL like they do the same thing." The Swell stays. |

## Spawning

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| First car | Seconds before each entry's first car, drawn per entry. With four entries the first car arrives about 3s in, so the first Switch is a calm one. | 2.5–4.5s | `FIRST_SPAWN` (inline) | #21 | |
| Spawn jitter | Each gap between cars on an entry is the spawn gap times a draw from this range. | 0.6–1.4× | `SPAWN_JITTER` (inline) | #21 | |
| Entry speed | A new car drives on at this share of base speed. A semi enters at its pace times this; a motorcycle no faster than a car, so it can stop behind the entry's queue (#30). | 0.8× | `SPAWN_SPEED` (inline) | #21 | |
| Entry room | Clear road an entry needs behind its last car before the next one drives on. Behind a car slower than it enters at, it also needs its stopping distance plus the follow gap (#30). | 4 px | `SPAWN_CLEAR` (inline) | #21 | |
| Entry point | How far past the map edge a new car's centre starts. A motorcycle or semi starts with its front bumper where a car's is, so a semi enters wholly out of sight (#30). | 24 px | `SPAWN_BACK` (inline) | #21 | |

## Driving

How cars move, follow and stop. Distances are measured along the car's route.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Base speed | Cruising speed, before the car speed knob. | 150 px/s | `BASE_SPEED` | #5 | |
| Go boost | Speed multiplier for a car waved through: its whole queue when the Light turns Green, or any car crossing the line on Green or Yellow. | 1.45× | `GO_BOOST` | #5 | |
| Acceleration | How fast a car gets up to speed. | 260 px/s² | `ACCEL` | #5 | |
| Braking | The comfortable braking that stops are planned with. | 420 px/s² | `DECEL` | #5 | |
| Hard braking | How many times harder than comfortable a driver brakes to shed speed, and when judging whether it can still stop for a Light. | 2× | `HARD_BRAKE` (inline) | #21 | |
| Look-ahead | How far ahead a driver watches for the car in front. | 220 px | `LOOK` | #5 | |
| Following gap | The bumper gap a driver stops short of the car in front. | 8 px | `FOLLOW_GAP` (inline) | #21 | |
| Stop margin | How far short of the stop line a driver stops. | 2 px | `STOP_MARGIN` (inline) | #21 | |
| Push-through floor | A driver slower than this always stops for Red or Yellow. A faster driver too close to stop braking hard pushes through. | 40 px/s | `PUSH_MIN_SPEED` (inline) | #21 | |
| Yellow caution | On Yellow a driver judges its stop as this many times longer, so more drivers push through. Yellow is a risk, not a free stop. | 2× | `YELLOW_CAUTION` (inline) | #21 | |
| Push slack | A driver within this of just making the stop still stops. | 1 px | `PUSH_SLACK` (inline) | #21 | |

## Crashes and Wreckage

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Crash inset | Each footprint shrinks by this on every side before the Crash check, so a graze doesn't count. | 2 px | `CRASH_INSET` (inline `grow(-2.0)`) | #22 | |
| Sight inset | A driver watches for Wreckage and the Raccoon across its own width, less this on each side. | 2 px | `SIGHT_INSET` (inline, `_strip`) | #22, #23 | |
| Sight step | Spacing of the points along its route where a driver looks for Wreckage and the Raccoon. | 4 px | `SIGHT_STEP` (not in the greybox) | #22, #23 | The greybox checked a straight strip ahead instead; points along the route also follow turns. |

## Turners

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Turner gap | Seconds of clear oncoming road a Turner wants before it goes: no oncoming car in the box, and none due at its stop line sooner. Higher values mean longer holds. Divided by the vehicle's pace: a slow semi waits for a longer gap, a motorcycle takes a shorter one (#30). | 1.4–2.0s, drawn per driver | `TURNER_GAP` (`GAP_MIN/MAX`) | #17, #24 | Holds of about 1–4s on green in headless runs. #24 soak, 25% Turners, N and S on Green for 90s: median hold 1.1–2.6s at the stage-1 spawn gap, up to about 18s at the stage-9 gap. |
| Gap judging speed | A Turner judges an oncoming car as arriving at least this fast, so a crawling or stopped car close to the line still counts as in the way. | 25 px/s | `GAP_MIN_SPEED` (inline) | #24 | |
| Hold point | A Turner pulls up with its centre on the stop line, nose in the box, and holds within this of that point. | 1 px | `HOLD_SLACK` (inline) | #24 | |
| Turn speed | Speed through a turn, left or right, as a share of normal speed. Normal speed includes the vehicle's pace (#30). A car turning right or left slows in time to enter the box at it. | 0.7× | `TURN_SPEED` | #9, #24 | |

## Right turns

Right turns happen everywhere, for natural-looking traffic ([#13](https://github.com/klusignolo/GameJam2026/issues/13)). They aren't a difficulty lever: a right-turning car obeys its Light (no turning on red), never waits for a gap, never holds up its lane, and signals with its right blinker. Where geometry leaves no straight exit (the T, some 5-way approaches), the route picker chooses among the movements the approach actually has. Since #32 the share of a movement an approach lacks goes straight on (a T's side road has no right or no left), or, with no straight exit (the T's stem, the 5-way's diagonal road), is split evenly between the movements it has. Where an approach has two routes making the same movement (a 5-way's second right or left), each gets half. A left turn whose road has no oncoming road (the T's stem, the diagonal) is still a Turner with an arrow, but never holds for a gap: there's no oncoming flow to wait for. While Turners are off (stages 1–2, or a generated stage that drew them off), left turns aren't offered at all: the T's stem all turns right.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Right-turn share | Share of drivers who turn right. It's drawn separately from the Turner share; everyone else goes straight. Flat from stage 1, with no Debut. | 15% | `RIGHT_SHARE` (not in the greybox) | #13, #24 | |

## Patience

Only the front driver at each red (or Yellow) Light spends Patience, plus a Turner holding for its gap, and only while stopped. Cars queued behind the front one have none. A driver who stops being the front driver (it crosses its line, or its Light turns Green) starts again from zero. Patience is spent in three equal stages: a Honk at the first third, a second Honk at two thirds, then Blowing the red once its Debut (stage 7) has come. Before then the front driver only Honks. Only the front driver at the line can Blow the red; a holding Turner only Honks. The per-stage Patience itself is the `K_PATIENCE` stage knob above.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Patience spread | Each driver's Patience is the stage's Patience times a draw from this range, so a row of red Lights doesn't Honk in unison. | 0.9–1.1× | `PATIENCE_JITTER` (inline, `_new_driver`) | #25 | |
| Patience stages | The equal stages Patience is spent in: Honk, second Honk, then out. | 3 | `PATIENCE_RINGS` | #14, #25 | |
| Waiting speed | A driver with Patience spends it only while slower than this. | 8 px/s | `WAIT_SPEED` (inline) | #25 | The greybox also gave back Patience at 2× while a metered driver moved faster than 40 px/s. Not ported: here a driver who stops being the front driver starts again from zero. |
| Blow reach | A driver out of Patience Blows the red once its front bumper is this close to the stop line. | 14 px | `BLOW_REACH` (inline) | #25 | |

## The Jam

One meter for the whole city ([#15](https://github.com/klusignolo/GameJam2026/issues/15)). Its fill must scale with map size ([#16](https://github.com/klusignolo/GameJam2026/issues/16)).

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Fill from waiting | Per second, for each front driver (or Turner) that has Honked. | 0.7/s after one Honk, 1.5/s after two | `JAM_HONK` | #15, #34 | #34: raised from 0.5 and 1.0 so an idle Raccoon gridlocks stage 1 in about 30s (#19). Over seeds 1–8 that went from 31–41s to 28–35s. The backlog fill barely moved it: at 1.0/s it only took about a second off. One Honk stays under the drain: two front drivers on their first Honk (1.4/s) can't beat one crossing's 1.5/s. |
| Fill from backlog | Per second, for each car that can't get onto the map. | 0.6/s | `JAM_BACKLOG` | #15, #27 | |
| Drain | Per second, always. **Scales with crossings** so a bigger map doesn't fill the Jam faster. | 1.5/s per crossing | `JAM_DRAIN` | #15, #16 | #16: with a flat 1.5/s, the Jam filled far too fast once the second crossing attached. Scaling by crossings was first tried in #17. |
| Drain per exit | A bonus for each car that leaves the map. | 0.4 | `JAM_EXIT` | #16 | |
| Dent | Jam capacity lost for good per Crash. | 2 (of 100) | `DENT` | #15, #26 | Kept small: Wreckage is the real punishment. |
| Capacity | The Jam's size before any Dents. | 100 | `JAM_CAP` | #15 | |
| Capacity floor | Dents never take the capacity below this. | 10 | `JAM_FLOOR` (inline in the greybox's `_cap()`) | #26 | Only matters after 45 Crashes in one Run. |
| Jam-levels | Where Busy and Heavy start, as a share of the capacity not lost to Dents. | Busy 40%, Heavy 70%; Gridlock when full | `JAM_BUSY`, `JAM_HEAVY` (inline in the greybox's `_level()`) | #15, #26 | #17: the Heavy pulse adds to the noise when every crossing is backed up. |

## Vehicle sizes

Footprints in world px. They're gameplay, not just art: a longer vehicle blocks the box for longer. The look is in [`docs/sprites.md`](sprites.md).

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Car | The standard vehicle. | 38 × 20 | `CAR_L`, `CAR_W` | #5 | Legible at ~0.66 zoom (#16). |
| Motorcycle | Small and fast; harder to see. | 22 × 10 | `MOTO_L`, `MOTO_W` | #6, #30 | First guess. |
| Semi | Long and slow; one rigid sprite, so its turn arc cuts the corner. | 84 × 24 | `SEMI_L`, `SEMI_W` | #6, #30 | First guess. |
| Raccoon | The player: kept at car scale so the hero reads. | 28 wide (sprite ~28 × 38) | `RACCOON_R` | #5, #6 | |

## Vehicle mix

Motorcycles debut at stage 5 and semis at stage 8 ([#30](https://github.com/klusignolo/GameJam2026/issues/30)). The `StageDef` carries the mix: each share is on while its feature is, and flat, not a stage curve. A vehicle's kind is drawn as it falls due at its entry, from its own random stream, so the mix never shifts any other seeded draw. Pace scales cruising, the Green boost and the turn speed. A semi also enters slower, while a motorcycle enters at a car's speed. A Turner's gap is divided by its pace, so a slow semi waits for a longer one. Every kind obeys the same rules otherwise. A Turner of any kind holds with its front bumper where a car's would be (a car's centre on the stop line), so a semi's nose stays out of the cross traffic.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Motorcycle share | Share of new vehicles that are motorcycles, from stage 5. | 15% | `MOTO_SHARE` | #30 | First guess. |
| Semi share | Share of new vehicles that are semis, from stage 8. The rest are cars. | 10% | `SEMI_SHARE` | #30 | First guess. |
| Motorcycle pace | A motorcycle's speed as a multiple of a car's. Faster, so the gaps around it close sooner. | ×1.3 | `MOTO_PACE` | #30 | First guess. |
| Semi pace | A semi's speed as a multiple of a car's. Slow and long, so it sits in the box longer and stacks a queue behind it. | ×0.75 | `SEMI_PACE` | #30 | First guess. |

## Roads

World px. One lane each way. At zoom 1, the map around one crossing fills the screen.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Arm length | From the crossing centre to the map edge: horizontal, then vertical. | 640, 360 | `ARM_X`, `ARM_Y` | #16 | |
| Link | Centre to centre between two linked crossings of the City plan, across and down. One lane each way, shared: one crossing's way out is the next one's way in. | 720 | `LINK` | #16, #31 | At six crossings the map is 2720 × 1530, about 0.49 zoom. |
| Map aspect | The map grows its short side to this around its crossings' arms, so entry roads run to the edge of the frame. | 16:9 | inline (`hy` in `_build`); `MAP_ASPECT` since #31 | #16, #31 | |
| Lane width | Each road is two lanes wide. | 30 | `LW` | #5 | |
| Stop line | From the crossing centre to the stop line. On an arm whose neighbour is less than a quarter turn away (the 5-way's diagonal and the two arms beside it), the stop line moves out until the two roads have parted as they do on a 4-way: by LW / tan(half the angle) − LW, so about 90 at 45°. Derived from `STOP_D` and `LW`, not a knob of its own. | 48 | `STOP_D`; `RoadNet.stop_distance()` since #32 | #5, #32 | |
| Pole position | Where a Light's pole stands: back from its stop line, and out past the kerb. The Raccoon targets this point. | 10 back, 14 out | `POLE_BACK`, `POLE_OUT` (inline) | #21 | |
| Exit margin | How far past the map edge a car drives before it leaves. | 60 | `EXIT_MARGIN` (inline) | #21 | |

## Raccoon

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Move speed | On-screen speed, constant at any zoom. | 230 px/s | `RACCOON_SPEED` | #15 | #16: travel between crossings felt like a chore, partly because Dash went unused. |
| Dash | Burst speed (on screen), how long it lasts and its cooldown, counted from the start of the Dash. | 640 px/s for 0.18s, 0.9s cooldown | `DASH_SPEED`, `DASH_TIME`, `DASH_COOLDOWN` (`DASH_CD`) | #5, #23 | #16: Space was added as Dash. |
| Targeting range | How close a Light must be to Switch it (on screen). | 160 px | `SIGNAL_RANGE` | #9 | |
| Start | Where the Raccoon starts, from the first crossing's centre. | 70, 70 world px | `RACCOON_START` (`r_pos`) | #21 | |
| Targeting bias | How much facing a Light counts toward picking it: a faced Light counts as up to this many px nearer. | 60 px | `TARGET_BIAS` (inline) | #9, #21 | |
| Tow range | How close to the footprint of Wreckage the Raccoon must be to Tow it (on screen). | 30 px | `TOW_RANGE` | #22 | |
| Tow hold | Towed Wreckage trails at most this far from the Raccoon. | 26 world px | `TOW_HOLD` (inline) | #22 | |
| Tow speed | The Raccoon's walk and Dash speed while towing. | 0.55× walk, 0.6× Dash | `TOW_SPEED`, `TOW_DASH` (inline) | #22 | |
| Off-road margin | Towed Wreckage whose centre is this far past the kerb is off the road, and is gone. | 10 world px | `ON_ROAD_MARGIN` (inline, `_on_road`) | #22 | |
| Yield margin | A driver Yields to the Raccoon when a line across its width, looking ahead from half a car back, comes within RACCOON_R plus this. It only widens the path: the driver stops short of the Raccoon's body by FOLLOW_GAP. | 8 world px | `YIELD_MARGIN` (`RACCOON_R - 6`) | #23 | |
| Hit | A car hits the Raccoon when the Raccoon's centre is within this of its footprint and the car is moving faster than the minimum. | 10 world px, over 30 world px/s | `HIT_REACH` (`RACCOON_R - 4`), `HIT_MIN_SPEED` (inline) | #23 | |
| Stun | How long a hit Raccoon can't act. | 0.8s | `STUN_TIME` (`r_stun`) | #23 | |
| Knockback | A hit knocks the Raccoon the way the car drives, slowing to a stop. | 420 world px/s, slowing by 900 px/s² | `KNOCK_SPEED`, `KNOCK_DECAY` (inline, on-screen px) | #23 | The greybox scaled these by 1/zoom; here they're world px, so the knockback shrinks on screen with the cars. |
| Yellow | How long a Light stays Yellow before falling to Red. | 1.5s | `YELLOW_TIME` | #5 | |

## Attract autopilot

How the Attract autopilot ([#34](https://github.com/klusignolo/GameJam2026/issues/34)) plays the Raccoon. It tows Wreckage near it off the road. Otherwise it picks the red Light with the most demand: cars on its approach short of the line, plus its entry's backlog. Before giving that Light Green, it Switches any crossing Green to Yellow, waits for Yellow to fall and for the box to clear, then Switches the goal. It waits and Switches from a post: the nearest spot to each pole that is off the road, so its own cars needn't Yield to it. These knobs don't touch gameplay. With them it clears stage 1 (seeds 1–3, about 65s) with no Crashes and the Jam near 0%.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Settle | It slows over this last stretch of a walk, so it settles instead of jittering. | 24 px | `AUTO_SETTLE` (no greybox autopilot) | #34 | |
| Walk cost | How far a walk counts as one waiting car when it picks the next Light. | 300 px | `AUTO_WALK_COST` | #34 | Only matters on maps with more than one crossing. |
| Shortest Green | A Green it turned on isn't cut short for a crossing Light sooner than this. | 4s | `AUTO_MIN_GREEN` | #34 | |
| Longest busy Green | A Green whose road is still at least as busy as the waiting one runs at most this long. | 12s | `AUTO_MAX_GREEN` | #34 | Cycling every road evenly (no such hold) let the Swell road's backlog build up, and the autopilot gridlocked stage 1 at about 55–73s. |
| Wreck reach | It tows Wreckage this close to it (on-screen px). | 360 px | `AUTO_WRECK_REACH` | #34 | |
| Tow give-up | After this long towing, it drops the Wreckage where it is. | 8s | `AUTO_TOW_GIVE_UP` | #34 | A guard against towing forever; not seen in headless runs. |

## Score and Combo

`Run` keeps the score ([#28](https://github.com/klusignolo/GameJam2026/issues/28)). Each car out adds 1 to Combo, then scores `EXIT_SCORE × (1 + Combo ÷ COMBO_STEP)`, with whole-number division. A Crash resets Combo; each `crashed` signal counts as one Crash, so a car hitting Wreckage counts as another.

| Knob | What it's for | Value | Greybox | Set by | Playtest notes |
|---|---|---|---|---|---|
| Exit score | Points per car that leaves the map, times the Combo multiplier. | 10 | `EXIT_SCORE` (inline) | #19, #28 | |
| Combo step | The multiplier goes up by 1 every this much Combo: ×1 at Combo 1–4, ×2 at 5–9, ×3 from 10. | 5 | `COMBO_STEP` (inline) | #19, #28 | |
| Tow bonus | Points for towing Wreckage off the road. Leaves Combo alone. | 5 | `TOW_BONUS` (inline) | #19, #28 | |

## Presentation tied to tuning

| Setting | Value | Set by | Notes |
|---|---|---|---|
| Patience ring | Hidden until the driver's first Honk. A ring around the car fills through the current stage (yellow, then red for the last); pips below count the stages gone: yellow, yellow, and red while "!!" shows | #17, #25 | A ring on every front car at red was noise by stage 4. Greybox drawing: `Vehicle.RING_R`, `PIP_DROP`. |
| HONK! | "HONK!" or "HONK HONK!" in ink on the `cue_honk` burst rises off the car and fades at each Honk | #25, #39 | `Vehicle.HONK_TIME`, `HONK_RISE`, `HONK_SIZE` (on-screen px). |
| Dash cooldown ring | Fills around the Raccoon while Dash cools down; gone once it's ready | #23 | |
| Turner arrow | An upright bubble over every Turner, pointing the way it will turn, from spawn until it starts its turn; bigger and pulsing signal yellow while it holds | #17, #24, #39 | The `cue_turner` bubble tinted, its arrow turned to the way out. `Vehicle.ARROW_R`, `ARROW_LIFT`, `PULSE_SPEED`. At 0.45× it's about 8 on-screen px: #41 judges it against the reference. |
| Swell chevrons | Triple chevrons by the kerb of the Swell road, in from the map edge, lit one after another toward the crossing like a marquee for as long as the Swell is on that road. No cue on the next Swell road before it moves | #14, #27, dev playtest after #28, #39 | Three `cue_swell` chevrons. `EntryCues.INSET`, `CHEVRON_OUT`, `MARQUEE_HZ`, `MARQUEE_DIM`. The dev: static or blinking chevrons "look like a power-up" to walk over and pick up. |
| Entry backlog | "+N" by an entry with cars waiting to get on; while the Jam is Heavy, the end of that lane pulses with a red outline | #19 (story 52), #27 | `EntryCues.TAG_OUT`, `TAG_SIZE`, `PULSE_LENGTH`, `PULSE_HZ`. |
| Right blinker | Flashes 2×/s at the front and back right corners from spawn until the car is through its turn | #13, #24 | `Vehicle.BLINK_HZ`; `blinker` colour from docs/sprites.md. |
| BONK! | Over the Raccoon for as long as it's stunned | #23 | Stands in for the greybox's floating "BONK" until the juice pass (#19 story 47). |
| Blowing-the-red warning | The car flashes "!!" for its last 3s of Patience, once Blowing the red has debuted. Blowing the red, the car is outlined red until it leaves the map or reaches the next crossing, where it's a fresh driver (#31) | #14, #25 | `BLOW_WARN`; `Vehicle.WARN_HZ`, `WARN_SIZE` (on-screen px). |
| HUD strip | A sign_blue band along the top: stage and Quota progress on the left, the Jam meter in the middle, score, Combo and its multiplier on the right, in white with an ink outline. Score moved right in #29: a 3-digit Quota ran into the Jam meter | #19 (story 73), #28, #29 | Greybox drawing: `HudStrip.HEIGHT`, `SIDE`, `TEXT_SIZE`. `EntryCues.INSET` keeps the N road's cues below it, in on-screen px since #31 so it holds at any zoom. |
| Tally card | Between stages, over the dimmed, frozen board: a sign_blue card with the stage cleared, cars through, score gained and a "NEW: <feature>!" line for each thing the next stage debuts, and "A: skip" | #19 (stories 59–60), #29 | Greybox drawing: `TallyCard.WIDTH`, `GAP`, `DIM`; Main puts it on canvas layer 2, over the HUD strip. Stands in for the stinger (#37 hooks `Traffic.stage_cleared`). |
| Reveal | 2.5s pull-back when a crossing attaches: the stage opens framing the old map and eases (smoothstep) out to the new one while traffic runs | #16, #33 | `REVEAL_TIME`. The whoosh and ka-chunk come in the Audio ticket. |
| Camera fit | Zoom 1.03× past "the whole map fits", so the map edges bleed off screen. Refit every tick, so a resized or wider window works; the "expand" stretch only widens or heightens the 1280×720 view, and the extra shows more city (#39) | #16, #33 | `FIT` |
| Readability floor | The camera never zooms out past 0.45; a map that would need more is followed instead, with the view held inside the map | #33 | `READ_FLOOR`. 0.45 is the zoom docs/sprites.md authors for. The whole plan fits above it (six crossings: about 0.485), so following is a safety net for now. Measured in the 1280×720 base view, not physical pixels: a small browser window shrinks everything further. |
| Camera drift | While fitting, the view drifts toward the Raccoon by 6% of its offset from the map centre, easing at rate 3/s, but never past the map edge, where cars appear. At 16:9 that caps it at the FIT bleed: about 1.5% of the map each way | #33 | `DRIFT`, `CAM_RATE`. The edge cap binds before 6% does near the map edges, so the drift is a small nudge. Raise `FIT` for more room. Following uses the same easing. |
| Crash burst | A `crash_burst` starburst with one word in ink (KRUNCH!, BONK!, SKRRT-BAM!, WHAM!, KA-CHUNK!), 110 on-screen px across at any zoom. It pops up from 60% size over 0.12s, then rises 30 px and fades over 1.2s. The same Crash always says the same word | #39 | `CrashMarker.LIFE`, `RISE`, `WIDE`, `POP`, `SIZE`, `FILL` (a long word shrinks to fit 60% of the burst). The juice pass (#43) adds the bits, smoke, freeze and shake. |
| Ground markings | Kerbs 3 px along every road edge; white centre dashes 10 on, 10 off; crosswalk stripes 5 px across, every 8.5 px, from 3 to 11 px past each stop line | #39 | `Ground.KERB_W`, `DASH`, `STRIPE`, `STRIPE_STEP`, `CROSSWALK`. |
| Uprights | The Raccoon shows its side view once its facing is 0.38 across (every diagonal), with a 24 × 10 shadow and an ink rope with a pale core; the lit lamp has a 6 px halo | #39 | `Raccoon.SIDE_FROM`, `SHADOW_R`, `ROPE_CORE`; `LightPole.GLOW_R`. |
| Body tints | Each vehicle draws one of the six safe tints in docs/sprites.md at spawn, evenly | #6, #39 | `Car.TINTS`. Drawn with `randf`, like the random hue it replaced, so every seeded stream stays put. |
| Rooftops | Roofs on a jittered 104 px grid over the map and 480 px past it, a quarter of the grid points left as open lots, each roof kept 12 px of pavement clear of every road and box | #39 | `Ground.ROOF_STEP` (more than the widest roof plus twice `ROOF_JITTER`), `ROOF_SKIP`, `ROOF_GAP`, `ROOF_SPREAD`. The first pass at 80 px with bright roofs fought the cars, so they're bigger, sparser and muted toward the pavement. Roads at the map edge run on `RUN_ON` past it. |

## Audio

Mix and playback numbers for the `Audio` autoload ([#12](https://github.com/klusignolo/GameJam2026/issues/12)). The sounds themselves and their recipes are in [`docs/audio.md`](audio.md). Mix levels per sound are set when the sounds exist; add a row each.

| Knob | What it's for | Value | Constant | Set by | Playtest notes |
|---|---|---|---|---|---|
| Groove tempo steps | The groove's `pitch_scale` at each Jam-level. Pitch rises with tempo. | Clear 1.0, Busy 1.06, Heavy 1.12 | `MUSIC_PITCH` | #12 | About 1 and 2 semitones up. If Heavy grates, fall back to a pre-stretched Heavy file. |
| Groove glide | How long the tempo takes to move to a new step. Also smooths the Jam bouncing across a band edge. | 1.5s | `MUSIC_GLIDE` | #12 | |
| SFX voice pool | SFX players in the pool. The music, the stinger and the Tow scrape have their own. | 16 | `SFX_VOICES` | #12 | |
| Honk cap | Honks that may sound at once. Past this, extra Honks carry no information. | 3 | `HONK_MAX` | #12 | |
| Retrigger guard | The same sound can't start again within this time. | 80 ms | `SFX_RETRIGGER` | #12 | Stops a pile-up from stacking identical crunches. |
| Crash duck | Music dip under each Crash. | −6 dB for 0.5s | `DUCK_CRASH` | #12 | |
| Stinger duck | Groove dip while the stage-clear stinger plays. | −9 dB for the stinger | `DUCK_STINGER` | #12 | First guess. |
| Pause duck | Groove level while paused. | −12 dB | `DUCK_PAUSE` | #12 | |
| Attract music | Theme level during Attract (no SFX in Attract). | 0 dB | `ATTRACT_MUSIC_DB` | #12 | Turn down if HCSS wants a quieter cabinet. |
| Pitch jitter | `pitch_scale` spread on Honks (fixed per car, from its id) and Crashes (random per Crash). | ±8% | `SFX_JITTER` | #12, #37 | First guess. |
| Yield squeal | A driver braking for the Raccoon squeals only if it was going at least this fast, once per stop. | 90 px/s | `YIELD_SQUEAL_SPEED` | #37 | 60% of a car's base speed: a car pulling away from a standstill into the Raccoon reaches about 65 px/s before it brakes, and shouldn't squeal. |
| Shatter delay | From the Gridlock record scratch to the glass shatter. | 0.5s | `SHATTER_DELAY` | #37 | A stand-in until the death beat (#43) times the shatter to its picture. |

**Mix levels** (#37): each SFX's player volume in dB, in `Sfx.SOUNDS` (`game/audio/sfx.gd`) next to its priority. Every clip is normalised to the same peak, so these alone set the mix. First guesses, set by ear on laptop speakers; tune on the cabinet.

| Sounds | dB |
|---|---|
| Crashes, Gridlock scratch and shatter | −2 |
| Raccoon hit | −3 |
| Switch (Green, Yellow), Tow grab, stinger | −4 |
| Blowing the red, reveal | −5 |
| Gridlock horns, Jam Heavy, Swell whistle | −6 |
| Second Honk | −7 |
| Dash, Combo break, Jam Busy | −8 |
| First Honk, UI confirm | −9 |
| Light falling to red, Combo blip | −10 |
| Yield squeal, UI move | −12 |
| Tow scrape (loop) | −14 |
