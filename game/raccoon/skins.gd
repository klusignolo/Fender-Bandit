class_name Skins
## The Raccoon's skins (#45, docs/sprites.md "Skins"): the crossing guard it starts in, and one more unlocked for
## every Tuning.SKIN_EVERY stages cleared, chosen on the title's Options. The crossing guard is the base art in
## res://art/; every other skin is the same rig parts, baked by tools/make_skins.gd into res://art/skins/<skin>/.

const GUARD := &"guard"
const ALL: Array[StringName] = [GUARD, &"burglar", &"cop", &"panda"]  # in unlock order
const FUR := Color("#8C93A3")  # the Raccoon's fur, from its sprites...
const FURS := {&"panda": Color("#9A7458")}  # ...and a skin's own, where it has one
const NAMES := {GUARD: "Crossing guard", &"burglar": "Cat burglar", &"cop": "Traffic cop", &"panda": "Trash panda"}


## The skins unlocked once stage `best_stage` has been cleared, in unlock order.
static func unlocked(best_stage: int) -> Array[StringName]:
	return ALL.slice(0, mini(1 + maxi(best_stage, 0) / Tuning.SKIN_EVERY, ALL.size()))


## The stage whose clearing unlocks `skin` (0 for the crossing guard).
static func unlock_stage(skin: StringName) -> int:
	return maxi(ALL.find(skin), 0) * Tuning.SKIN_EVERY


## The fur colour `skin` wears, e.g. for the title Raccoon's paws.
static func fur(skin: StringName) -> Color:
	return FURS.get(skin, FUR)


## `base`, a Raccoon texture in res://art/, as `skin` wears it.
static func texture(base: Texture2D, skin: StringName) -> Texture2D:
	if skin == GUARD or not skin in ALL:
		return base
	return load("res://art/skins/%s/%s" % [skin, base.resource_path.get_file()]) as Texture2D
