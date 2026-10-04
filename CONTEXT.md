# Game Jam 2026

**Fender Bandit** is an arcade game where the player, as a raccoon tampering with traffic lights, keeps a growing web of intersections flowing through stage after stage until it collapses into a pile-up.

## Language

### The player

**Raccoon**:
The player-controlled character who roams the intersections flipping their traffic lights and clearing up after crashes.
_Avoid_: Player character, crossing guard, guard, cursor

**Light**:
The traffic signal for one approach into a crossing, always Red, Green or Yellow; drivers obey it, not the raccoon.
_Avoid_: Signal, lamp, Stop/Go

**Switch**:
The raccoon's one move on a light: Red turns Green, Green turns Yellow, and Yellow falls to Red on its own.
_Avoid_: Toggle, flip, Stop, Go

**Dash**:
A short burst of raccoon speed for reaching a light or a wreck in time.
_Avoid_: Sprint, run (reserved for a play session), boost

**Tow**:
The raccoon dragging a piece of wreckage out of the traffic.
_Avoid_: Drag, clear, pull

### Play session

**Run**:
One play session: a series of stages, from the first car to gridlock.
_Avoid_: Game, session, playthrough

**Stage**:
One leg of a run, cleared by meeting its quota; the world grows a piece on Debut stages, and each stage is never easier than the last.
_Avoid_: Level, round, wave, shift

**Quota**:
The number of cars a stage needs to get through before it is cleared.
_Avoid_: Target, goal, car count

**Tally**:
The card between stages: the stage cleared, its cars through and score, and what the next stage debuts.
_Avoid_: Stage summary, interstitial, scorecard

**Opening**:
The fixed first stages of every run, identical each time, before stages are generated.
_Avoid_: Tutorial, campaign, intro

**Debut**:
The stage that introduces a new feature on its own, holding everything else steady.
_Avoid_: Unlock stage, feature stage

**Attract**:
The self-running intersection shown behind the title while no one is playing.
_Avoid_: Demo mode, idle screen, splash

**High-score table**:
The local list of the top ten initials and scores.
_Avoid_: Leaderboard (the online kind is out of scope), scoreboard

**Rush hour**:
The escalation from stage to stage, with no ceiling.
_Avoid_: Difficulty, wave, level

**Gridlock**:
The end of a run: the Jam is full (jam-level Gridlock).
_Avoid_: Game over, death, loss

**Jam**:
The city-wide meter of traffic trouble, filled by waiting cars and entry backlog and drained while traffic flows; a full Jam is Gridlock.
_Avoid_: Anger, congestion meter, pressure, health

**Jam-level**:
The band the Jam is in: Clear, Busy, Heavy, then Gridlock when full.
_Avoid_: Danger level, threat, stage (a stage is a leg of a run)

**Dent**:
A small, permanent loss of Jam capacity left by each Crash.
_Avoid_: Scar, strike, damage

**Combo**:
The multiplier built by consecutive cars getting through safely; a crash resets it.
_Avoid_: Streak, chain, multiplier (as a noun for the mechanic)

### Traffic

**City plan**:
The one hand-authored layout of up to six crossings that a Run's map grows into, one crossing at a time, in a fixed order.
_Avoid_: Level, map layout, grid

**Arm**:
One road leaving a crossing, at the angle the City plan gives it; each arm has a lane in (its approach) and a lane out. A 4-way has four, a T three and a 5-way five.
_Avoid_: Leg, side, spoke

**Link**:
The road joining two neighbouring crossings: a car leaving one crossing that way arrives at the other.
_Avoid_: Connector (a movement through one crossing's box), street

**Entry**:
A road coming in from the map edge, where new cars appear; the Quota counts them.
_Avoid_: Spawn, source

**Swell**:
One road carrying a heavy share of the traffic for part of a stage, then shifting to another road, announced by a whistle a moment before it moves and marked at the road edge while it lasts.
_Avoid_: Wave, rush (Rush hour is the escalation), surge

**Reveal**:
The camera pulling back from the old map to the grown one as a stage opens with a new crossing attached.
_Avoid_: Zoom-out, intro, transition

**Readability floor**:
The furthest the camera will zoom out; a map that would need more is followed around the Raccoon instead of fitted.
_Avoid_: Min zoom, zoom limit

### Drivers

**Patience**:
How long the front driver at a red Light will wait, in three stages: a Honk, a second Honk, then Blowing the red. Drivers queued behind the front one have no Patience.
_Avoid_: Anger, impatience, timer

**Honk**:
A driver's warning that their patience is running out.
_Avoid_: Beep, horn

**Blowing the red**:
The front driver, out of Patience, driving through a red Light regardless of cross traffic. It arrives as a Debut; before it, the front driver only Honks.
_Avoid_: Running the red (run is reserved for a play session), red-light running

**Turner**:
A driver turning left from the shared lane, who waits in the crossing for a gap in oncoming traffic and holds up everyone behind; flagged by an icon that pulses once it is stuck.
_Avoid_: Left-turner, turning car, yielding (Yield is braking for the raccoon)

**Vehicle mix**:
The share of new vehicles that are cars, motorcycles (small and fast, from stage 5) and semis (long and slow, from stage 8), set per Stage. Every kind follows the same driving rules; a semi is one rigid rectangle, so it cuts its turns.
_Avoid_: Car type, traffic mix (traffic covers movements too)

**Yield**:
A driver braking for the raccoon in their path; a driver moving too fast to stop in time hits it instead.
_Avoid_: Stopping for, avoiding

### Accidents

**Crash**:
A collision between vehicles; the game's comedic payoff and the seed of the player's downfall.
_Avoid_: Accident, collision, wreck (as a verb)

**Wreckage**:
Crashed vehicles left in place as obstacles until towed, making further crashes more likely.
_Avoid_: Debris, obstacles, wreck
