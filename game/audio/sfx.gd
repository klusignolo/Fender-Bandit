class_name Sfx
## The sound list (#37, docs/audio.md "Sound list"): every SFX Audio plays, with its VoicePool priority and its mix
## level in dB (docs/tuning.md "Audio"). tools/make_sfx.gd writes each one to res://audio/sfx/<name>.wav.

const P := VoicePool.Priority
const DIR := "res://audio/sfx/"

const SOUNDS: Dictionary[StringName, Array] = {
	# Raccoon
	&"switch_green": [P.PLAYER, -4.0],
	&"switch_yellow": [P.PLAYER, -4.0],
	&"dash": [P.PLAYER, -8.0],
	&"tow_grab": [P.PLAYER, -4.0],
	&"tow_scrape": [P.PLAYER, -14.0],  # its own looping player, outside the pool
	&"raccoon_hit": [P.HIT, -3.0],
	# Lights and drivers
	&"light_red": [P.OTHER, -10.0],
	&"honk_1": [P.HONK, -9.0],
	&"honk_2": [P.HONK, -7.0],
	&"blow_red": [P.BLOW, -5.0],
	&"yield": [P.OTHER, -12.0],
	# Crashes
	&"crash_1": [P.CRASH, -2.0],
	&"crash_2": [P.CRASH, -2.0],
	&"crash_3": [P.CRASH, -2.0],
	&"gridlock_scratch": [P.GRIDLOCK, -2.0],
	&"gridlock_horns": [P.GRIDLOCK, -6.0],
	&"gridlock_shatter": [P.GRIDLOCK, -2.0],
	# Run and world
	&"combo_up": [P.OTHER, -10.0],
	&"combo_break": [P.OTHER, -8.0],
	&"jam_busy": [P.OTHER, -8.0],
	&"jam_heavy": [P.OTHER, -6.0],
	&"swell": [P.OTHER, -6.0],
	&"reveal": [P.OTHER, -5.0],
	&"stinger": [P.OTHER, -4.0],  # its own player, outside the pool; a placeholder until #38's Lyria stinger
	# UI
	&"ui_move": [P.OTHER, -12.0],
	&"ui_confirm": [P.OTHER, -9.0],
}


static func path(sound: StringName) -> String:
	return DIR + sound + ".wav"


static func priority(sound: StringName) -> VoicePool.Priority:
	return SOUNDS[sound][0]


static func db(sound: StringName) -> float:
	return SOUNDS[sound][1]
