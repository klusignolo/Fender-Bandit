class_name Tuning
## Every tuning number from docs/tuning.md, under the register's constant names.
## Grows ticket by ticket; keep it in step with the register.

# Audio
const MUSIC_PITCH: Array[float] = [1.0, 1.06, 1.12]  # groove pitch_scale at Clear, Busy, Heavy
const MUSIC_GLIDE := 1.5  # seconds to glide to a new MUSIC_PITCH step
