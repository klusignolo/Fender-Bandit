class_name ScoreTable
extends RefCounted
## The High-score table (#36, #19 stories 17–18): the top SIZE initials and scores, best first, with the Music
## On/Off setting (story 78), the chosen Raccoon skin and the best stage cleared (which unlocks skins, #45) beside them, kept in a ConfigFile at `path`. A Run ranks if it scored and beats
## tenth place; a tie goes below the score already there. The Scores autoload holds the game's one.

const SIZE := 10
const FORMAT := 2  # the save's format: a table saved without it holds scores from before honk scoring (#45), so it starts empty

var entries: Array[Dictionary] = []  # {initials: String, score: int}, best first
var music := true
var skin := Skins.GUARD  # the Raccoon's skin, one of those best_stage has unlocked
var best_stage := 0  # the furthest stage any Run has cleared (a cheated one aside)
var path := ""


## The table saved at `path`, or an empty one. A file that won't read gives an empty table, with music on.
func _init(p: String) -> void:
	path = p
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path) or cfg.load(path) != OK:
		return
	var m: Variant = cfg.get_value("settings", "music", true)
	music = m if m is bool else true
	var b: Variant = cfg.get_value("settings", "best_stage", 0)
	best_stage = b if b is int else 0
	var s: Variant = cfg.get_value("settings", "skin", String(Skins.GUARD))
	skin = StringName(s) if s is String and StringName(s) in Skins.unlocked(best_stage) else Skins.GUARD
	if cfg.get_value("scores", "format", 1) != FORMAT:
		return  # older scores can't be compared with these: keep only the Music setting
	var table: Variant = cfg.get_value("scores", "table", [])
	if not table is Array:
		return
	for e: Variant in table:  # placed one by one, not sorted: sort_custom isn't stable, and a tie keeps its order
		if e is Dictionary and e.get("initials") is String and e.get("score") is int and e.score > 0:
			_place((e.initials as String).substr(0, InitialsEntry.SLOTS), e.score)


## Where `score` would go in the table, or -1 if it doesn't make the top SIZE.
func rank_of(score: int) -> int:
	if score <= 0:
		return -1
	for i in entries.size():
		if score > entries[i].score:
			return i
	return entries.size() if entries.size() < SIZE else -1


func ranks(score: int) -> bool:
	return rank_of(score) >= 0


## Puts `initials` and `score` in the table and saves it; returns its rank, or -1 if it didn't make it.
func add(initials: String, score: int) -> int:
	var r := _place(initials, score)
	if r >= 0:
		save()
	return r


## Puts the entry in its place, below any tie, and drops what falls off the end; returns its rank, or -1.
func _place(initials: String, score: int) -> int:
	var r := rank_of(score)
	if r >= 0:
		entries.insert(r, {"initials": initials, "score": score})
		entries.resize(mini(entries.size(), SIZE))
	return r


func set_music(on: bool) -> void:
	music = on
	save()


## Wear `s` from now on, if it's unlocked.
func set_skin(s: StringName) -> void:
	if s in Skins.unlocked(best_stage):
		skin = s
		save()


## A Run cleared `stage`: returns the skin that unlocks, if any, or &"".
func cleared(stage: int) -> StringName:
	if stage <= best_stage:
		return &""
	var had := Skins.unlocked(best_stage).size()
	best_stage = stage
	save()
	var now := Skins.unlocked(best_stage)
	return now[now.size() - 1] if now.size() > had else &""


## Best effort: a failed write is logged and the table plays on from memory.
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "table", entries)
	cfg.set_value("scores", "format", FORMAT)
	cfg.set_value("settings", "music", music)
	cfg.set_value("settings", "skin", String(skin))
	cfg.set_value("settings", "best_stage", best_stage)
	var err := cfg.save(path)
	if err != OK:
		push_warning("Couldn't save the High-score table to %s: %s" % [path, error_string(err)])
	elif OS.has_feature("web"):
		JavaScriptBridge.force_fs_sync()  # user:// is IndexedDB: write it through now, before the tab can close
