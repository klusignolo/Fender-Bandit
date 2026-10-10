class_name Tuning
## Every tuning number from docs/tuning.md, under the register's constant names.
## Grows ticket by ticket; keep it in step with the register.

# Stage knobs: [stage 1, stage 9, far limit]. Stages (#29) reads them.
const K_GAP: Array[float] = [3.2, 1.0, 0.6]  # spawn gap per entry, seconds
const K_SPEED: Array[float] = [1.0, 1.4, 2.0]  # car speed multiplier
const K_TURNERS: Array[float] = [0.10, 0.20, 0.25]  # Turner share; unlike the others its first value is stage 3, and before that it is zero
const K_PATIENCE: Array[float] = [15.0, 12.0, 7.0]  # seconds a front driver waits at red before it's out of Patience
const K_EASE := 0.85  # per stage past 9, the share of the gap to the far limit left

# Stage length and Quota
const TARGET_LEN := 24.0  # seconds every stage should last if traffic flows (#45: flat, so stages stay short)
const TALLY_TIME := 3.0  # seconds the Tally card shows before the next stage...
const TALLY_LOCK := 0.5  # ...and A skips it only after this long, so a Switch mashed as the stage clears doesn't

# The arcade loop (#35)
const SKIN_EVERY := 3  # stages cleared per new Raccoon skin (#45): clearing 3 unlocks the second, 6 the third, 9 the fourth
const ATTRACT_TIME := 60.0  # seconds an Attract plays before a fresh one starts (Gridlock starts one sooner)
const CONTROLS_TIME := 6.0  # seconds the controls card shows before the Run starts...
const CONTROLS_LOCK := 0.5  # ...and A closes it only after this long, so the press that left Attract doesn't
const GRIDLOCK_HOLD := 2.8  # seconds from Gridlock to the results, with input locked: the Gridlock beat up to its shards falling (#43)
const RESULTS_TIME := 10.0  # seconds the results card shows before Attract...
const RESULTS_LOCK := 1.5  # ...and A skips it only after this long

# Crash juice and the Gridlock beat (#43). The beat is timed in seconds of real time from the Gridlock.
const CRASH_FREEZE := 4  # physics ticks the board freezes on each Crash: about 60 ms
const SHAKE_PX := 9.0  # on-screen px the camera shakes at full trauma...
const SHAKE_CRASH := 0.55  # ...the trauma each Crash adds, up to 1 (the shake goes as its square)...
const SHAKE_DECAY := 2.0  # ...and the trauma lost per second
const SHAKE_HZ := 18.0  # the shake's wobbles per second
const GRIDLOCK_SLOWMO := 0.25  # the engine time scale as traffic coasts on into the pile-up...
const GRIDLOCK_LURCH := 60.0  # ...every car, even one stopped in a queue, lurching on at least this many world px/s
const GRIDLOCK_PILEUP_AT := 0.8  # every car crashes at once...
const GRIDLOCK_BURSTS := 10  # ...with a burst on at most this many of them
const GRIDLOCK_CRACK_AT := 1.4  # the frame freezes, washes out and cracks, with the glass shatter
const GRIDLOCK_BANNER_AT := 1.65  # the GRIDLOCK banner slams in; the shards fall at GRIDLOCK_HOLD...
const GRIDLOCK_FALL_TIME := 1.0  # ...and are gone this long after

# The High-score table (#36)
const INITIALS_TIME := 30.0  # seconds to enter initials before they save as InitialsEntry.DEFAULT ("RAC")...
const INITIALS_LOCK := 0.75  # ...and A enters a letter only after this long, so A mashed through the results doesn't
const REPEAT_DELAY := 0.4  # seconds up or down is held before a letter starts to repeat...
const REPEAT_EVERY := 0.1  # ...and then a step this often
const SCORES_TIME := 8.0  # seconds the table shows after a Run, the new entry flashing, before Attract...
const SCORES_LOCK := 1.0  # ...and A skips it only after this long

# The generator, past stage 9
const FLOOR_START := 2  # features a generated stage turns on at least, at stage 10...
const FLOOR_EVERY := 4  # ...and 1 more every this many stages, up to all of them
const CROSSING_EVERY := 4  # a crossing attaches every this many stages after stage 9...
const CROSSINGS_MAX := 6  # ...up to this many

# Spawning
const FIRST_SPAWN: Array[float] = [2.5, 4.5]  # seconds before each entry's first car, drawn per entry
const SPAWN_JITTER: Array[float] = [0.6, 1.4]  # each spawn gap is K_GAP times a draw from this range
const SPAWN_SPEED := 0.8  # a new car enters at this share of BASE_SPEED
const SPAWN_CLEAR := 4.0  # room an entry needs behind its last car before the next one drives on
const SPAWN_BACK := 24.0  # a new car's centre starts this far past the map edge

# Swells
const SWELL_HEAVY := 2.0  # the Swell road's spawn rate, as a multiple of k_gap's...
const SWELL_LIGHT := 0.67  # ...and every other road's
const SWELL_MIN := 20.0  # seconds a road stays the Swell road, drawn per Swell from SWELL_MIN to SWELL_MAX
const SWELL_MAX := 30.0
const SHIFT_WARN := 1.0  # seconds before the Swell moves that its next road is flagged: the whistle, nothing on screen

# Roads (world px)
const ARM_X := 640.0  # entry arm length, centre to map edge, horizontal
const ARM_Y := 360.0  # ...vertical
const LINK := 720.0  # centre to centre, between linked crossings in the City plan
const MAP_ASPECT := 16.0 / 9.0  # the map widens its short side to this, so entry roads run to the edge of the frame
const LW := 30.0  # lane width; each road is two lanes, out | in
const STOP_D := 48.0  # crossing centre to stop line
const POLE_BACK := 10.0  # a Light hangs this far back from its stop line...
const POLE_OUT := 14.0  # ...and this far out past the kerb
const EXIT_MARGIN := 60.0  # how far past the map edge a car drives before it leaves

# Cars
const CAR_L := 38.0
const CAR_W := 20.0
const MOTO_L := 22.0  # a motorcycle: small and fast
const MOTO_W := 10.0
const MOTO_PACE := 1.3  # its speed as a multiple of a car's, cruising and through turns
const SEMI_L := 84.0  # a semi: long and slow, one rigid rectangle
const SEMI_W := 24.0
const SEMI_PACE := 0.75
const MOTO_SHARE := 0.15  # share of new vehicles that are motorcycles, once they've debuted (stage 5)...
const SEMI_SHARE := 0.10  # ...and semis (stage 8)...
const GARBAGE_L := 56.0  # a garbage truck (#46): between a car and a semi, one rigid rectangle
const GARBAGE_W := 24.0
const GARBAGE_PACE := 0.85
const GARBAGE_SHARE := 0.10  # ...and garbage trucks (stage 6); the rest are cars
const PICKUP_TIME := 2.0  # seconds a garbage truck stands at its pickup point, once per crossing, holding up its lane
const PICKUP_BEFORE := 90.0  # px its centre stops short of the stop line: clear of the box and the crosswalk
const BASE_SPEED := 150.0  # px/s, before K_SPEED
const GO_BOOST := 1.45  # speed multiplier once a car has been waved through on green
const ACCEL := 260.0  # px/s²
const DECEL := 420.0  # px/s², the comfortable braking that stopping is planned with; cars can brake twice as hard
const LOOK := 220.0  # how far ahead a driver watches for the car in front
const FOLLOW_GAP := 8.0  # bumper gap a driver stops short of the car in front
const STOP_MARGIN := 2.0  # how far short of the stop line a driver stops
const PUSH_MIN_SPEED := 40.0  # below this a driver always stops for Red or Yellow
const HARD_BRAKE := 2.0  # how many times DECEL a driver brakes at to hold a lower speed, or to judge a stop it can still make
const YELLOW_CAUTION := 2.0  # on Yellow a driver judges its stop as this many times longer, so more push through
const PUSH_SLACK := 1.0  # px: a driver this close to just making the stop still stops

# Crashes and Wreckage
const CRASH_INSET := 2.0  # each footprint shrinks by this on every side before the Crash check, so a graze doesn't count
const SIGHT_INSET := 2.0  # a driver watches for Wreckage and the Raccoon across its own width, less this on each side
const SIGHT_STEP := 4.0  # px between the points along its route where a driver looks for Wreckage and the Raccoon

# Turns
const RIGHT_SHARE := 0.15  # share of drivers who turn right, flat from stage 1
const TURN_SPEED := 0.7  # speed through a turn, as a share of normal speed
const TURNER_GAP: Array[float] = [1.4, 2.0]  # seconds of clear oncoming road a Turner wants before it goes, drawn per driver
const GAP_MIN_SPEED := 25.0  # px/s: a Turner judges an oncoming car as arriving at least this fast
const HOLD_SLACK := 1.0  # px: a Turner this close to its hold point (centre on the stop line) is holding there

# Patience
const PATIENCE_JITTER: Array[float] = [0.9, 1.1]  # each driver's Patience is K_PATIENCE times a draw from this range
const PATIENCE_RINGS := 3  # Patience is spent in this many equal stages: Honk, second Honk, then out
const BLOW_REACH := 14.0  # px: a driver out of Patience Blows the red once its front bumper is this close to the line
const BLOW_WARN := 5.0  # seconds of Patience left when a hothead starts flashing "!!" (#45: was 3s)
const HOTHEAD_SHARE := 0.25  # share of drivers who are hotheads: only they Blow the red; the rest only Honk (#45)
const WAIT_SPEED := 8.0  # px/s: a driver with Patience spends it only while slower than this

# The Jam
const JAM_CAP := 100.0  # the Jam's capacity before Dents
const DENT := 2.0  # Jam capacity each Crash takes away for good
const JAM_FLOOR := 10.0  # Dents never take the capacity below this
const JAM_BUSY := 0.4  # the Jam is Busy from this share of the capacity left after Dents...
const JAM_HEAVY := 0.7  # ...and Heavy from this share; full is Gridlock
const JAM_HONK: Array[float] = [0.0, 0.7, 1.5]  # fill per second for each driver Honking, by its Honks so far
const JAM_BACKLOG := 0.6  # fill per second for each car waiting in an entry's backlog
const JAM_DRAIN := 1.5  # drain per second, always, for each crossing on the map
const JAM_EXIT := 0.4  # drain for each car that leaves the map

# Lights
const YELLOW_TIME := 1.5  # seconds a Light stays Yellow before falling to Red

# Raccoon (on-screen px: world values scale with 1/zoom)
const RACCOON_R := 14.0
const RACCOON_SPEED := 230.0
const DASH_SPEED := 640.0  # on-screen px/s for the length of a Dash
const DASH_TIME := 0.18  # seconds a Dash lasts
const DASH_COOLDOWN := 0.9  # seconds from the start of one Dash until the next can start
const SIGNAL_RANGE := 160.0  # how close a Light's pole must be to Switch it
const TARGET_BIAS := 60.0  # how much facing a Light counts toward picking it, in px of distance
const RACCOON_START := Vector2(70, 70)  # world px from the first crossing's centre
const TOW_RANGE := 30.0  # how close to the footprint of Wreckage the Raccoon must be to Tow it
const TOW_HOLD := 26.0  # world px: towed Wreckage trails at most this far from the Raccoon
const TOW_SPEED := 0.55  # the Raccoon's walking speed while towing, as a share of RACCOON_SPEED
const TOW_DASH := 0.6  # its Dash speed while towing, as a share of DASH_SPEED
const ON_ROAD_MARGIN := 10.0  # world px: towed Wreckage whose centre is this far past the kerb is off the road
const YIELD_MARGIN := 8.0  # world px: a driver Yields to the Raccoon this far beyond RACCOON_R
const HIT_REACH := 10.0  # world px: a car hits the Raccoon when its centre is this close to the car's footprint...
const HIT_MIN_SPEED := 30.0  # ...and the car is faster than this, world px/s
const STUN_TIME := 0.8  # seconds a hit Raccoon is stunned
const KNOCK_SPEED := 420.0  # world px/s a hit knocks the Raccoon back at, the way the car drives...
const KNOCK_DECAY := 900.0  # ...slowing by this much each second

# Attract autopilot (#34)
const AUTO_SETTLE := 24.0  # world px: it slows over this last stretch to where it's walking, so it settles
const AUTO_WALK_COST := 300.0  # world px of walk that count as one waiting car when it picks the next Light
const AUTO_MIN_GREEN := 4.0  # seconds a Green it turned on runs before it will cut it short for a crossing Light
const AUTO_MAX_GREEN := 12.0  # ...and runs at most this long while its road is still busier than the one waiting
const AUTO_WRECK_REACH := 360.0  # on-screen px: it tows Wreckage this close to it
const AUTO_TOW_GIVE_UP := 8.0  # seconds of towing before it drops the Wreckage wherever it is

# Score and Combo
const EXIT_SCORES: Array[int] = [15, 10, 5]  # points per car out by the most Honks it reached on its way, times the Combo multiplier (#45)
const COMBO_STEP := 5  # the multiplier goes up 1 every this much Combo: ×1, then ×2 from 5, ×3 from 10...
const TOW_BONUS := 5  # points for Wreckage towed off the road

# Camera
const FIT := 1.03  # zoom a touch past "fits everything", so the map edges bleed off
const READ_FLOOR := 0.45  # the camera never zooms out past this; a map that would need more is followed instead
const CUE_MIN_ZOOM := 0.75  # past this zoom out, floating cues stop shrinking: they hold the size they have here (#41)
const RACCOON_MIN_ZOOM := 0.7  # likewise the Raccoon, so the hero and its animations read at the floor (#41)
const DRIFT := 0.06  # while fitting, the view drifts toward the Raccoon by this share of its offset from the map centre
const CAM_RATE := 3.0  # per second: how fast the view eases toward where it should be (exponential)
const REVEAL_TIME := 2.5  # seconds the pull-back takes when a crossing attaches

# Audio
const MUSIC_PITCH: Array[float] = [1.0, 1.06, 1.12]  # groove pitch_scale at Clear, Busy, Heavy
const MUSIC_GLIDE := 1.5  # seconds to glide to a new MUSIC_PITCH step
const SFX_VOICES := 16  # SFX players in the pool; the music, the stinger and the Tow scrape have their own
const HONK_MAX := 3  # Honks that may sound at once
const SFX_RETRIGGER := 0.08  # seconds before the same sound may start again
const DUCK_CRASH: Array[float] = [-6.0, 0.5]  # music dip under each Crash: dB, seconds
const DUCK_STINGER := -9.0  # dB the music dips while the stinger plays
const DUCK_PAUSE := -12.0  # dB the music sits at while paused
const ATTRACT_MUSIC_DB := 0.0  # the Theme's level under Attract
const SFX_JITTER := 0.08  # pitch_scale spread on Honks (per car) and Crashes (per Crash)
const YIELD_SQUEAL_SPEED := 90.0  # px/s: a car braking for the Raccoon from at least this fast squeals
