class_name Tuning
## Every tuning number from docs/tuning.md, under the register's constant names.
## Grows ticket by ticket; keep it in step with the register.

# Stage knobs: [stage 1, stage 9, far limit]. Only the stage-1 values are used until Stages (#29).
const K_GAP: Array[float] = [3.2, 1.0, 0.6]  # spawn gap per entry, seconds
const K_SPEED: Array[float] = [1.0, 1.4, 2.0]  # car speed multiplier

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

# Lights
const YELLOW_TIME := 1.5  # seconds a Light stays Yellow before falling to Red

# Raccoon (on-screen px: world values scale with 1/zoom)
const RACCOON_R := 14.0
const RACCOON_SPEED := 230.0
const SIGNAL_RANGE := 160.0  # how close a Light's pole must be to Switch it
const TARGET_BIAS := 60.0  # how much facing a Light counts toward picking it, in px of distance
const RACCOON_START := Vector2(70, 70)  # world px from the first crossing's centre

# Camera
const FIT := 1.03  # zoom a touch past "fits everything", so the map edges bleed off

# Audio
const MUSIC_PITCH: Array[float] = [1.0, 1.06, 1.12]  # groove pitch_scale at Clear, Busy, Heavy
const MUSIC_GLIDE := 1.5  # seconds to glide to a new MUSIC_PITCH step
