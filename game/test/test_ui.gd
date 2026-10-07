extends TestCase
## The UI art pass (#42, docs/sprites.md "Type and UI"): every screen is a road sign set in Bungee, laid out so its
## words stay readable at the 1280×720 base; the HUD strip fits its worst case; the icon is the Raccoon Crossing
## diamond and every build wears it; the font's licence ships with it.

const VIEW := Vector2(1280, 720)  # the base, and the smallest view aspect expand gives
const LONG_SCORE := 9999999


# --- the screens -----------------------------------------------------------------

## One of every screen and state, filled with the longest values a Run can give.
func _screens() -> Dictionary:
	var run := Run.new()
	run.stage = 99
	run.cars_through = 9999
	run.top_combo = 999
	run.most_crashes = 99
	run.score = LONG_SCORE
	var news := PackedStringArray(Stages.NAMES.values())
	news.append(Stages.GROW_NAME)
	var table: Array[Dictionary] = []
	for i in ScoreTable.SIZE:
		table.append({"initials": "WWW", "score": LONG_SCORE})
	var out := {
		"title": TitleScreen.new(),
		"controls, pad": ControlsCard.new(true),
		"controls, keys": ControlsCard.new(false),
		"pause, music on": PauseMenu.new(true),
		"pause, music off": PauseMenu.new(false),
		"results": ResultsCard.new(run),
		"initials": InitialsScreen.new(InitialsEntry.new(), LONG_SCORE, ScoreTable.SIZE - 1),
		"scores": ScoresScreen.new(table, 0),
	}
	for n in news:  # each news line alone, then two: a stage debuts one feature at most, and may grow a crossing too
		out["tally, %s" % n] = TallyCard.new(99, 9999, LONG_SCORE, PackedStringArray([n]))
	out["tally, two news"] = TallyCard.new(99, 9999, LONG_SCORE, PackedStringArray([Stages.NAMES[Stages.Feature.ODD_JUNCTIONS], Stages.GROW_NAME]))
	return out


func test_every_screen_lays_out_on_signs_inside_the_base_view() -> void:
	var screens := _screens()
	for name: String in screens:
		var card: Card = screens[name]
		card.measure(VIEW)
		check(not card.signs.is_empty(), "%s: is drawn on a sign" % name)
		for t: Card.Words in card.words:
			var label := "%s: \"%s\"" % [name, t.text]
			check(Rect2(Vector2.ZERO, VIEW).encloses(t.rect), "%s at %s is on screen" % [label, t.rect])
			check(t.size >= Card.MIN_TEXT, "%s is at least %d px (got %d)" % [label, Card.MIN_TEXT, t.size])
			if not t.loose:
				var inside := false
				for s: Rect2 in card.signs:
					inside = inside or Sign.inner(s).encloses(t.rect)
				check(inside, "%s at %s sits inside a sign's white rule" % [label, t.rect])
		for i in card.words.size():
			for j in range(i + 1, card.words.size()):
				var a: Card.Words = card.words[i]
				var b: Card.Words = card.words[j]
				check(not a.rect.intersects(b.rect), "%s: \"%s\" and \"%s\" don't overlap" % [name, a.text, b.text])
		card.free()


func test_the_title_is_the_logo_lockup() -> void:
	var title := TitleScreen.new()
	title.measure(VIEW)
	var texts := title.words.map(func(w: Card.Words) -> String: return w.text)
	check("FENDER" in texts and "BANDIT" in texts, "the logo reads FENDER BANDIT: %s" % [texts])
	check("STOP. GO. OOPS." in texts, "with the tagline: %s" % [texts])
	check(not title.stripes.is_empty(), "on construction stripes, a Raccoon moment")
	title.free()


func test_a_new_feature_on_the_tally_wears_construction_stripes() -> void:
	var plain := TallyCard.new(1, 10, 100, PackedStringArray())
	plain.measure(VIEW)
	check(plain.stripes.is_empty(), "no news, no stripes")
	var news := TallyCard.new(1, 10, 100, PackedStringArray([Stages.GROW_NAME]))
	news.measure(VIEW)
	check_eq(news.stripes.size(), 1, "one NEW badge")
	plain.free()
	news.free()


# --- the HUD strip -------------------------------------------------------------------

func test_the_hud_strip_fits_its_longest_values_at_the_base_width() -> void:
	var left := HudStrip.left_text(99, 999, 999)
	var right := HudStrip.right_text(LONG_SCORE, 999, 9)
	var parts := HudStrip.layout(VIEW.x, left, right)
	var meter := JamMeter.footprint(VIEW.x)
	for p: Rect2 in parts:
		check(Rect2(0, 0, VIEW.x, HudStrip.HEIGHT).encloses(p), "%s is on the strip" % p)
		check(not p.intersects(meter.grow(8.0)), "%s keeps clear of the Jam meter at %s" % [p, meter])
	check(not parts[0].intersects(parts[1]), "left and right don't meet")


# --- type --------------------------------------------------------------------------

func test_every_word_is_set_in_bungee() -> void:
	check_eq(Sign.FONT.get_font_name(), "Bungee", "the sign font")
	for path in _scripts("res://"):
		var src := FileAccess.get_file_as_string(path)
		check(not src.contains("fallback_font"), "%s draws with Sign.FONT, not the fallback font" % path)


func test_the_font_ships_with_its_licence() -> void:
	check(FileAccess.file_exists("res://art/fonts/OFL.txt"), "the OFL text sits beside the font")
	check(FileAccess.get_file_as_string("res://art/fonts/OFL.txt").contains("SIL OPEN FONT LICENSE Version 1.1"), "and is the OFL 1.1")


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with(".") and d != "build" and d != "test":
			out.append_array(_scripts(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


# --- the icon ----------------------------------------------------------------------

func test_the_icon_is_the_raccoon_crossing_diamond() -> void:
	check_eq(ProjectSettings.get_setting("application/config/icon"), "res://icon.svg", "the window icon")
	var img := Image.new()
	check_eq(img.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), 0.125), OK, "the icon loads at 16 px")
	check_eq(img.get_size(), Vector2i(16, 16), "16 px")
	check_eq(img.get_pixel(0, 0).a, 0.0, "a diamond: its corners are clear")
	check_eq(img.get_pixel(15, 15).a, 0.0, "all of them")
	var orange := 0
	var navy := 0
	for y in 16:
		for x in 16:
			var c := img.get_pixel(x, y)
			if c.a > 0.9 and c.r > 0.85 and c.g > 0.35 and c.g < 0.6 and c.b < 0.25:
				orange += 1
			elif c.a > 0.9 and c.r < 0.2 and c.g < 0.2 and c.b < 0.35:
				navy += 1
	check(orange >= 30, "orange construction ground reads at 16 px (%d px)" % orange)
	check(navy >= 15, "and the navy raccoon and border (%d px)" % navy)


func test_every_build_wears_the_icon() -> void:
	var presets := ConfigFile.new()
	check_eq(presets.load("res://export_presets.cfg"), OK, "export presets load")
	for section in presets.get_sections():
		if not section.ends_with(".options"):
			continue
		var preset := section.trim_suffix(".options")
		check(String(presets.get_value(preset, "include_filter", "")).contains("art/fonts/OFL.txt"), "%s packs the font's licence" % preset)
		var platform: String = presets.get_value(preset, "platform", "")
		if platform == "Web":
			check(presets.get_value(section, "html/export_icon", false), "the favicon is the icon")
		elif platform == "Windows Desktop":
			check(presets.get_value(section, "application/modify_resources", false), "the exe takes the icon")
			check_eq(presets.get_value(section, "application/icon", ""), "", "from config/icon, so there's one source")


func test_the_itch_thumbnail_is_rendered() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/art/itch-thumbnail.png")
	var img := Image.load_from_file(path)
	if check(img != null, "docs/art/itch-thumbnail.png exists"):
		check_eq(img.get_size(), Vector2i(630, 500), "at itch's cover size")
