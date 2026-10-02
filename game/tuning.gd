class_name Tuning
## Every tuning number from docs/tuning.md, under the register's constant names.
## Grows ticket by ticket; keep it in step with the register.

# Stage knobs: [stage 1, stage 9, far limit]. Only the stage-1 values are used until Stages (#29).
const K_GAP: Array[float] = [3.2, 1.0, 0.6]  # spawn gap per entry, seconds
const K_SPEED: Array[float] = [1.0, 1.4, 2.0]  # car speed multiplier
const K_TURNERS: Array[float] = [0.10, 0.20, 0.25]  # Turner share; unlike the others its first value is stage 3, and before that it is zero
const K_PATIENCE: Array[float] = [15.0, 12.0, 7.0]  # seconds a front driver waits at red before it's out of Patience

# Spawning
const FIRST_SPAWN: Array[float] = [2.5, 4.5]  # seconds before each entry's first car, drawn per entry
const SPAWN_JITTER: Array[float] = [0.6, 1.4]  # each spawn gap is K_GAP times a draw from this range
const SPAWN_SPEED := 0.8  # a new car enters at this share of BASE_SPEED
const SPAWN_CLEAR := 4.0  # room an entry needs behind its last car before the next one drives on
const SPAWN_BACK := 24.0  # a new car's centre starts this far past the map edge

# Roads (world px)
const ARM_X := 640.0  # entry arm length, centre to map edge, horizontal
const ARM_Y := 360.0  # ...vertical
const LW := 30.0  # lane width; each road is two lanes, out | in
const STOP_D := 48.0  # crossing centre to stop line
const POLE_BACK := 10.0  # a Light hangs this far back from its stop line...
const POLE_OUT := 14.0  # ...and this far out past the kerb
const EXIT_MARGIN := 60.0  # how far past the map edge a car drives before it leaves

# Cars
const CAR_L := 38.0
const CAR_W := 20.0
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
const BLOW_WARN := 3.0  # seconds of Patience left when a driver who will Blow the red starts flashing "!!"
const WAIT_SPEED := 8.0  # px/s: a driver with Patience spends it only while slower than this

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

# Camera
const FIT := 1.03  # zoom a touch past "fits everything", so the map edges bleed off

# Audio
const MUSIC_PITCH: Array[float] = [1.0, 1.06, 1.12]  # groove pitch_scale at Clear, Busy, Heavy
const MUSIC_GLIDE := 1.5  # seconds to glide to a new MUSIC_PITCH step
