# Traffic is a plain-code simulation; nodes only draw it

Crossings, Lights, Cars, the Jam and the Quota are plain GDScript classes (`game/sim/`), stepped by one `Traffic` object at a fixed 60 Hz. Scene nodes read that state each frame and draw it, and they never decide anything. Events reach the view, audio and score as signals on `Traffic`. We chose this over node-native cars (`CharacterBody2D`/`PathFollow2D` with physics Crash detection) for three reasons. The greybox's queueing, gap, Yield and Turner logic already works in this form. Those rules fight a physics engine. And a pure simulation can be tested and run headless, which matters when agents write and check the code. Decided in [#13](https://github.com/klusignolo/Fender-Bandit/issues/13).

## Consequences

- Crash detection is our own oriented-rectangle check, not `Area2D` overlaps. It only compares cars on conflicting connectors in the same crossing box, plus Wreckage.
- Cars move along `Curve2D` route segments by distance (`sample_baked_with_rotation`), not by physics.
- The Raccoon is the exception. It's a node that moves itself, and it feeds its position and Dash state to the simulation each tick. Switch and Tow go in as method calls, so every rule stays in the simulation.
