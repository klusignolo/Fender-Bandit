class_name MusicMix
extends RefCounted
## The music's state (#38, docs/audio.md "Music cues"): which track plays, the groove's tempo gliding with the
## Jam-level (MUSIC_PITCH over MUSIC_GLIDE), and the player's level from the ducks, Pause and Music On/Off. Audio
## holds one and applies it to its music player each frame; it touches no player, so it's tested on its own.

enum Track { NONE, THEME, GROOVE }

const SILENT := -80.0  # dB: Music Off, or no track
const DIR := "res://audio/music/"
const FILES: Dictionary[Track, String] = {Track.THEME: "theme.ogg", Track.GROOVE: "groove.ogg"}

var track := Track.NONE
var on := true  # Music On/Off (Scores keeps it)
var attract := false  # the Theme under Attract plays at ATTRACT_MUSIC_DB
var pitch := 1.0  # the music player's pitch_scale
var _pitch_to := 1.0
var _rate := 0.0  # pitch_scale per second, toward _pitch_to


static func path(t: Track) -> String:
	return DIR + FILES[t]


## Play `t`; returns whether the player must start it. The track already playing plays on, so the Theme runs from
## the Results through the table into Attract, and the groove across a Run's stages. A new groove starts at
## Clear's tempo; the Theme always plays at 1.0.
func play(t: Track, under_attract := false) -> bool:
	attract = under_attract
	if t == track:
		return false
	track = t
	pitch = 1.0
	_pitch_to = 1.0
	return t != Track.NONE


func stop() -> void:
	play(Track.NONE)


## The Jam moved to `level`: the groove glides to its step, in MUSIC_GLIDE whatever the distance. Gridlock holds
## Heavy's (the record scratch is about to stop it anyway).
func set_level(level: Jam.Level) -> void:
	if track != Track.GROOVE:
		return
	_pitch_to = Tuning.MUSIC_PITCH[mini(level, Tuning.MUSIC_PITCH.size() - 1)]
	_rate = absf(_pitch_to - pitch) / Tuning.MUSIC_GLIDE


func step(dt: float) -> void:
	pitch = move_toward(pitch, _pitch_to, _rate * dt)


## The player's level in dB, under a duck of `duck_db` (0 for none), and Pause's when `paused`: the deepest wins.
func volume_db(duck_db: float, paused: bool) -> float:
	if not on or track == Track.NONE:
		return SILENT
	var base := Tuning.ATTRACT_MUSIC_DB if attract else 0.0
	return base + minf(duck_db, Tuning.DUCK_PAUSE if paused else 0.0)
