extends TestCase
## The sprite proof (#18, game/tools/sprite_proof.sh): its lineup shows every sprite the proof judges, drawn by the
## game's own nodes, and its filter switch reaches every canvas item, the top-level cues and smoke too.

const Proof := preload("res://tools/sprite_proof.gd")


func _vehicles(lineup: Node) -> Array[Vehicle]:
	var out: Array[Vehicle] = []
	for n in lineup.find_children("*", "Vehicle", true, false):
		out.append(n as Vehicle)
	return out


func test_the_lineup_shows_every_tint_kind_lamp_and_wreck() -> void:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	var lineup: Node2D = Proof.lineup(t)
	var tints := {}
	var kinds := {}
	var wrecks := {}
	var braking := false
	var blinking := false
	for v in _vehicles(lineup):
		v._process(0.0)
		if v.car.kind == Car.Kind.CAR and not v.car.wreckage:
			tints[v.car.tint] = true
		kinds[v.car.kind] = true
		if v.car.wreckage:
			wrecks[v.car.kind] = true
		braking = braking or v.brake.visible
		blinking = blinking or v._blink_side() != 0.0
	check_eq(tints.size(), Car.TINTS.size(), "an intact car in each safe tint")
	check_eq(kinds.size(), 3, "a car, a motorcycle and a semi")
	check_eq(wrecks.size(), 3, "Wreckage of each kind")
	check(braking, "one shows its brake lamps")
	check(blinking, "one is turning, so it blinks")
	lineup.free()


func test_the_lineup_shows_every_raccoon_view_and_light_state() -> void:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	var lineup: Node2D = Proof.lineup(t)
	var views := {}
	var anims := {}
	for n in lineup.find_children("*", "RaccoonRig", true, false):
		var rig := n as RaccoonRig
		views[rig.view] = true
		anims[rig.anim] = true
	check_eq(views.size(), 4, "the Raccoon's front, back, side and mirrored side")
	check_eq(anims.size(), RaccoonRig.Anim.size(), "and a pose from each of its six animations")
	var states := {}
	for p in lineup.find_children("*", "LightPole", true, false):
		states[(p as LightPole).light.state] = true
	check_eq(states.size(), 3, "a pole lit red, yellow and green")
	lineup.free()


func test_the_filter_switch_reaches_every_canvas_item() -> void:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	var lineup: Node2D = Proof.lineup(t)
	Proof.set_filter(lineup, CanvasItem.TEXTURE_FILTER_LINEAR)
	var items := lineup.find_children("*", "CanvasItem", true, false)
	check(items.size() > 20, "the lineup has its sprites: %d items" % items.size())
	for n in items:
		check_eq((n as CanvasItem).texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "%s's filter" % n.name)
	lineup.free()


func test_the_backdrop_is_ground_under_the_stop_lines_and_shadows() -> void:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	var lineup: Node2D = Proof.lineup(t)
	var ground := lineup.get_node_or_null("Ground") as Node2D
	if check(ground != null, "the backdrop is its own Ground node"):
		check_eq(ground.z_index, Art.Z_GROUND, "on the ground layer")
		check(not ground.z_as_relative, "as an absolute z, like the game's")
	var shadow := lineup.get_node_or_null("RaccoonFront/Shadow") as Node2D
	if check(shadow != null, "the Raccoon's shadow is named for its view"):
		check_eq(shadow.z_index, Art.Z_SHADOW, "on the shadow layer")
	lineup.free()
