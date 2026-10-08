extends Node
## The Audio autoload (#37, docs/audio.md "Playback rules"): a music player for the Theme and groove (#38), a
## stinger player, a Tow-scrape loop and a pool of SFX_VOICES SFX players booked by VoicePool. Main has it watch each
## stage's World: a BoardCues turns the board's signals into cues. An Attract board is muted (#19 story 80), so
## Attract has no SFX; the UI's own sounds still play. Ducking is done with player volume, never bus effects, and
## every clip plays in the default playback mode (Sample on the web): see docs/audio.md "Web limits". In the browser
## nothing sounds until the first press, unless the page already allows sound (itch.io's "Run game" click can).

signal played(sound: StringName)  # a sound started: the smoke test listens
signal music_started(track: MusicMix.Track)  # the Theme or groove started from the top: the smoke test listens

var _pool := VoicePool.new(Tuning.SFX_VOICES)
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _music := AudioStreamPlayer.new()
var _stinger := AudioStreamPlayer.new()
var _scrape := AudioStreamPlayer.new()
var _mix := MusicMix.new()
var _tracks: Dictionary[MusicMix.Track, AudioStream] = {}
var _cues: BoardCues  # the watched board's
var _board_muted := false
var _clock := 0.0  # seconds since boot, Pause included: VoicePool's time
var _duck_db := 0.0  # how far the music is ducked, until _duck_until
var _duck_until := 0.0
var _unlocked := not OS.has_feature("web") or _autoplay_allowed()  # else the browser plays nothing until the first press: music waits for it


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sounds finish over Pause and the frozen boards
	for sound: StringName in Sfx.SOUNDS:
		_streams[sound] = load(Sfx.path(sound))
	for i in Tuning.SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for t: MusicMix.Track in MusicMix.FILES:
		_tracks[t] = load(MusicMix.path(t))
	_music.volume_db = MusicMix.SILENT
	add_child(_music)
	_stinger.stream = _streams[&"stinger"]
	_stinger.volume_db = Sfx.db(&"stinger")
	add_child(_stinger)
	_scrape.stream = _streams[&"tow_scrape"]
	_scrape.volume_db = Sfx.db(&"tow_scrape")
	add_child(_scrape)


## Stop every sound. The audio server lets go of a stopped clip on its next mix, so quitting straight after it
## still leaks the clips that were playing: give it a moment first (test/smoke.gd does).
func silence() -> void:
	for p: AudioStreamPlayer in _voices + [_music, _stinger, _scrape]:
		p.stop()
	_mix.stop()


func _process(delta: float) -> void:
	_clock += delta
	_scrape.stream_paused = get_tree().paused
	_mix.step(delta)
	_music.pitch_scale = _mix.pitch
	_music.volume_db = _mix.volume_db(_duck_db if _clock < _duck_until else 0.0, get_tree().paused)


## The first press: in the browser, audio can play from now on. Music asked for before it doesn't start until asked again.
func unlock() -> void:
	_unlocked = true


## Music On/Off (Scores keeps the setting). Off, the music plays on silent, so On picks it up where it is.
func set_music_on(on: bool) -> void:
	_mix.on = on


## Play the Theme or the groove, or stop the music (NONE). The track already playing plays on, from where it is.
## `under_attract` puts the Theme at Attract's level.
func music(track: MusicMix.Track, under_attract := false) -> void:
	if not _unlocked:
		return
	if not _mix.play(track, under_attract):
		if track == MusicMix.Track.NONE:
			_music.stop()
		return
	_music.stream = _tracks[track]
	_music.pitch_scale = _mix.pitch
	_music.play()
	music_started.emit(track)


## Play SFX `sound` (a name from Sfx.SOUNDS) at `pitch`, if VoicePool gives it a voice. Returns whether it plays.
func play(sound: StringName, pitch := 1.0) -> bool:
	if sound == &"stinger":
		_scrape.stop()  # the board has frozen under the Tally card
		_stinger.play()
		_duck(Tuning.DUCK_STINGER, _stinger.stream.get_length())
		played.emit(sound)
		return true
	var stream := _streams[sound]
	var v := _pool.request(sound, Sfx.priority(sound), stream.get_length() / pitch, _clock)
	if v < 0:
		return false
	var p := _voices[v]
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = Sfx.db(sound)
	p.play()
	if Sfx.priority(sound) == VoicePool.Priority.CRASH:
		_duck(Tuning.DUCK_CRASH[0], Tuning.DUCK_CRASH[1])
	played.emit(sound)
	return true


## Listen to `world`'s board from now on, and drop the last one's. `muted` (an Attract board) plays none of its SFX.
## Call it once the World is in the tree: its Raccoon is built in _ready. A stage whose crossing attached plays the Reveal.
func watch(world: World, muted: bool) -> void:
	_scrape.stop()
	_board_muted = muted
	_cues = BoardCues.new(world.traffic, world.run, world.raccoon)
	_cues.cue.connect(_on_cue)
	_cues.scrape.connect(_on_scrape)
	_cues.jam.connect(_on_jam)
	if world.reveals():
		_on_cue(&"reveal", 1.0)


## Gridlock: the record scratch cuts the music dead on the slow-mo, under a chorus of horns. The GridlockBeat plays
## the pile-up's Crashes and the glass shatter on its picture (#43).
func gridlock() -> void:
	_scrape.stop()
	music(MusicMix.Track.NONE)
	play(&"gridlock_scratch")
	play(&"gridlock_horns")


func _duck(db: float, seconds: float) -> void:
	_duck_db = minf(db, _duck_db) if _clock < _duck_until else db
	_duck_until = maxf(_duck_until, _clock + seconds)


func _on_cue(sound: StringName, pitch: float) -> void:
	if not _board_muted:
		play(sound, pitch)


func _on_jam(level: Jam.Level) -> void:
	if not _board_muted:
		_mix.set_level(level)


func _on_scrape(on: bool) -> void:
	if on and not _board_muted:
		_scrape.play()
	else:
		_scrape.stop()


## Whether the browser lets this page play sound before any press: a fresh AudioContext starts "running" when the
## page has autoplay, e.g. on itch.io, whose embed allows it and whose "Run game" click is the user gesture (#45).
## Godot's own context is under the same policy. Elsewhere it starts "suspended" and the first press unlocks.
static func _autoplay_allowed() -> bool:
	var running = JavaScriptBridge.eval("""
		(function () {
			var A = window.AudioContext || window.webkitAudioContext;
			if (!A) return false;
			var c = new A();
			var ok = c.state === "running";
			c.close();
			return ok;
		})()
	""", true)
	print("Web autoplay allowed: %s" % [running])  # in the browser console: why the Theme did or didn't start at boot
	return running == true
