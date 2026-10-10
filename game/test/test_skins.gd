extends TestCase
## Raccoon skins (#45, docs/sprites.md "Skins"): one unlocks per SKIN_EVERY stages cleared, the High-score save keeps
## the choice and the best stage cleared, and every skin has every part of the rig.

const PATH := "user://test_skins.cfg"


func _fresh() -> ScoreTable:
	DirAccess.remove_absolute(PATH)
	return ScoreTable.new(PATH)


func test_a_skin_unlocks_every_three_stages_cleared() -> void:
	for x: Array in [[0, 1], [2, 1], [3, 2], [5, 2], [6, 3], [9, 4], [21, 4]]:  # best stage cleared, skins
		check_eq(Skins.unlocked(x[0]).size(), x[1], "%d skins after clearing stage %d" % [x[1], x[0]])
	check_eq(Skins.unlocked(0), [Skins.GUARD] as Array[StringName], "the crossing guard from the start")
	check_eq(Skins.unlock_stage(Skins.ALL[1]), Tuning.SKIN_EVERY, "the second skin: clear stage SKIN_EVERY")


func test_every_skin_has_every_part_of_the_rig() -> void:
	for skin: StringName in Skins.ALL:
		check(Skins.NAMES.has(skin), "%s has a name" % skin)
		for view: Raccoon.View in [Raccoon.View.FRONT, Raccoon.View.BACK, Raccoon.View.RIGHT]:
			for p: Array in RaccoonRig._PARTS[view]:
				var tex := Skins.texture(p[1], skin)
				check(tex != null and tex.get_size() == (p[1] as Texture2D).get_size(), "%s: %s" % [skin, p[1].resource_path.get_file()])
		check(Skins.texture(Art.RACCOON_FRONT, skin) != null, "%s: the whole front sprite, for the title" % skin)
	check(Skins.texture(Art.RACCOON_FRONT, Skins.GUARD) == Art.RACCOON_FRONT, "the crossing guard is the base art")
	check(Skins.texture(Art.RACCOON_FRONT, &"cop") != Art.RACCOON_FRONT, "a skin has its own")


func test_clearing_a_stage_unlocks_the_next_skin_once() -> void:
	var t := _fresh()
	check_eq(t.best_stage, 0, "nothing cleared yet")
	check_eq(t.cleared(2), &"", "stage 2: nothing new")
	check_eq(t.cleared(3), Skins.ALL[1], "stage 3: the second skin")
	check_eq(t.cleared(3), &"", "stage 3 again: nothing new")
	check_eq(t.cleared(1), &"", "an earlier stage: nothing new")
	check_eq(t.best_stage, 3, "the best stage stays the best")
	DirAccess.remove_absolute(PATH)


func test_the_skin_and_the_best_stage_survive_a_reload() -> void:
	var t := _fresh()
	t.cleared(6)
	t.set_skin(&"cop")
	var again := ScoreTable.new(PATH)
	check_eq(again.best_stage, 6, "the best stage cleared")
	check_eq(again.skin, &"cop", "the chosen skin")
	DirAccess.remove_absolute(PATH)


func test_a_skin_not_unlocked_or_not_known_wears_the_crossing_guard() -> void:
	var t := _fresh()
	t.set_skin(&"panda")
	check_eq(t.skin, Skins.GUARD, "a locked skin can't be chosen")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "skin", "astronaut")
	cfg.set_value("settings", "best_stage", 9)
	cfg.save(PATH)
	check_eq(ScoreTable.new(PATH).skin, Skins.GUARD, "an unknown skin in the file")
	DirAccess.remove_absolute(PATH)


func test_the_rig_wears_the_skin_it_is_given() -> void:
	var rig := RaccoonRig.new()
	var head := func() -> Texture2D: return (rig._parts[Raccoon.View.FRONT][&"head"] as Sprite2D).texture
	check(head.call() == RaccoonRig._PARTS[Raccoon.View.FRONT][6][1], "the crossing guard by default")
	rig.set_skin(&"burglar")
	check(head.call() == Skins.texture(RaccoonRig._PARTS[Raccoon.View.FRONT][6][1], &"burglar"), "the burglar's head")
	rig.set_skin(Skins.GUARD)
	check(head.call() == RaccoonRig._PARTS[Raccoon.View.FRONT][6][1], "and back")
	rig.free()
