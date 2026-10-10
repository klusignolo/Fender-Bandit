extends SceneTree
## Bakes the Raccoon's skins (#45, docs/sprites.md "Skins"): for each skin but the crossing guard (the base art), every
## Raccoon SVG in res://art/ is rewritten as text, a colour swap and then costume shapes injected on the part's shared
## 64×84 canvas, to res://art/skins/<skin>/<the same file name>. So each skin has the same parts, pivots and
## animations as the base. Each file gets the base's import settings (mipmaps on). Rerun it after changing a base
## Raccoon SVG or a recipe below, then let Godot import:
##   godot --headless --path game -s tools/make_skins.gd
##   godot --headless --path game --import

const ART := "res://art/"
const VEST := "#FF7A1A"
const STRIPE := "#EEF1F6"
const FUR := "#8C93A3"

## Per skin: colour swaps, and per file stem an SVG fragment appended inside <svg>, in canvas px. "@vest" in a
## fragment is the file's vest path data, to clip a pattern to the vest. The whole-sprite raccoon_front (the title's
## peeking Raccoon, the Options preview) takes its front head's and front body's fragments.
const RECIPES := {
	&"burglar": {
		"swap": {VEST: "#F4F1E8", STRIPE: "#22252E"},
		"add": {
			"raccoon_front_body": "@stripes",
			"raccoon_side_body": "@stripes",
			"raccoon_back_body": "@stripes" + '<path d="M38,50 C46,46 54,52 52,62 C50,70 38,70 36,62 C34,56 34,52 38,50 Z" fill="#C9B28A" stroke="#1B2340" stroke-width="2.5"/><path d="M37,51 L40,47 L43,50" fill="none" stroke="#1B2340" stroke-width="2"/><path d="M42,57 L42,66 M44.5,58.5 C41,57 39,59.5 42,61 C45,62.5 43.5,65 40,64" fill="none" stroke="#1B2340" stroke-width="1.6" stroke-linecap="round"/>',
			"raccoon_front_head": '<path d="M14,23 C13,7 51,7 50,23 Z" fill="#22252E" stroke="#1B2340" stroke-width="2.5"/><path d="M13,18 L51,18 L51,23 L13,23 Z" fill="#363B4D" stroke="#1B2340" stroke-width="2"/>',
			"raccoon_back_head": '<path d="M14,24 C13,7 51,7 50,24 Z" fill="#22252E" stroke="#1B2340" stroke-width="2.5"/><path d="M13,19 L51,19 L51,24 L13,24 Z" fill="#363B4D" stroke="#1B2340" stroke-width="2"/>',
			"raccoon_side_head": '<path d="M16,25 C14,10 32,5 44,15 L44,22 Z" fill="#22252E" stroke="#1B2340" stroke-width="2.5"/><path d="M15,21 L45,18 L45,23 L16,26 Z" fill="#363B4D" stroke="#1B2340" stroke-width="2"/>',
		},
	},
	&"cop": {
		"swap": {VEST: "#2B3E7A", STRIPE: "#1B2340"},
		"add": {
			"raccoon_front_body": '<circle cx="24" cy="49" r="3" fill="#F2C230" stroke="#1B2340" stroke-width="1.5"/><path d="M18,62 L46,62 L46,65 L18,65 Z" fill="#1B2340"/><circle cx="32" cy="63.5" r="1.6" fill="#F2C230"/>',
			"raccoon_side_body": '<circle cx="36" cy="49" r="3" fill="#F2C230" stroke="#1B2340" stroke-width="1.5"/><path d="M18,62 L43,62 L43,65 L18,65 Z" fill="#1B2340"/>',
			"raccoon_back_body": '<path d="M18,62 L46,62 L46,65 L18,65 Z" fill="#1B2340"/>',
			"raccoon_front_head": '<path d="M16,17 C14,4 50,4 48,17 Z" fill="#2B3E7A" stroke="#1B2340" stroke-width="2.5"/><path d="M16,15 L48,15 L48,20 L16,20 Z" fill="#1B2340"/><circle cx="32" cy="11" r="2.8" fill="#F2C230" stroke="#1B2340" stroke-width="1.2"/><path d="M18,20 Q32,27 46,20 Z" fill="#11162A"/>',
			"raccoon_back_head": '<path d="M16,17 C14,4 50,4 48,17 Z" fill="#2B3E7A" stroke="#1B2340" stroke-width="2.5"/><path d="M16,15 L48,15 L48,20 L16,20 Z" fill="#1B2340"/>',
			"raccoon_side_head": '<path d="M18,19 C17,7 38,4 45,14 L45,17 Z" fill="#2B3E7A" stroke="#1B2340" stroke-width="2.5"/><path d="M18,16 L46,14 L46,19 L18,21 Z" fill="#1B2340"/><path d="M45,17 L55,21 L45,20 Z" fill="#11162A" stroke="#1B2340" stroke-width="1.5"/><circle cx="34" cy="11" r="2.4" fill="#F2C230"/>',
		},
	},
	&"panda": {
		"swap": {FUR: "#9A7458", "#5E6577": "#5C4434", "#5E6A80": "#6E4F3A", "#4E5567": "#4A3628", "#2A2F45": "#2E2220",
				"#E6E9F0": "#F0E2CC", VEST: "#3B5A40", STRIPE: "#3B5A40"},
		"add": {
			"raccoon_front_body": '<path d="M22,46 L26,52 L23,57 M41,47 L38,53 L42,60" fill="none" stroke="#1B2340" stroke-width="1.5"/><path d="M30,60 C29,64 33,66 35,63 C36,61 34,58 30,60 Z" fill="#E8D44D" stroke="#1B2340" stroke-width="1.2"/>',
			"raccoon_side_body": '<path d="M24,47 L28,53 L25,58" fill="none" stroke="#1B2340" stroke-width="1.5"/>',
			"raccoon_back_body": '<path d="M24,48 L28,54 L25,59 M40,49 L37,55 L41,61" fill="none" stroke="#1B2340" stroke-width="1.5"/>',
			"raccoon_front_head": '<g transform="rotate(-10 32 12)"><ellipse cx="32" cy="12" rx="22" ry="5" fill="#A8AEB8" stroke="#1B2340" stroke-width="2.5"/><path d="M14,12 Q32,16 50,12 M18,10 Q32,13 46,10" fill="none" stroke="#6E7480" stroke-width="1"/><path d="M27,8 Q32,1 37,8" fill="none" stroke="#1B2340" stroke-width="2.5"/></g><path d="M46,16 C52,20 54,28 50,34 C50,28 48,22 44,19 Z" fill="#E8D44D" stroke="#1B2340" stroke-width="1.5"/>',
			"raccoon_back_head": '<g transform="rotate(-10 32 12)"><ellipse cx="32" cy="12" rx="22" ry="5" fill="#A8AEB8" stroke="#1B2340" stroke-width="2.5"/><path d="M27,8 Q32,1 37,8" fill="none" stroke="#1B2340" stroke-width="2.5"/></g>',
			"raccoon_side_head": '<g transform="rotate(-12 31 12)"><ellipse cx="31" cy="12" rx="20" ry="3.5" fill="#A8AEB8" stroke="#1B2340" stroke-width="2.5"/><path d="M27,9 Q31,3 35,9" fill="none" stroke="#1B2340" stroke-width="2.5"/></g>',
		},
	},
}


func _initialize() -> void:
	var import_params := _import_params(ART + "raccoon_front_head.svg.import")
	for skin: StringName in RECIPES:
		var dir := ART + "skins/%s/" % skin
		DirAccess.make_dir_recursive_absolute(dir)
		var n := 0
		for file in DirAccess.get_files_at(ART):
			if file.begins_with("raccoon_") and file.ends_with(".svg") and file != "raccoon_star.svg":
				_write(dir + file, _skinned(FileAccess.get_file_as_string(ART + file), file.get_basename(), RECIPES[skin]))
				if not FileAccess.file_exists(dir + file + ".import"):
					_write(dir + file + ".import", '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n' + import_params)
				n += 1
		print("%s: %d parts" % [skin, n])
	quit()


static func _skinned(svg: String, stem: String, recipe: Dictionary) -> String:
	var vest := ""
	var m := RegEx.create_from_string('d="([^"]+)" fill="%s"' % VEST).search(svg)
	if m:
		vest = m.get_string(1)
	for from: String in recipe.swap:
		svg = svg.replace(from, recipe.swap[from])
	var add := ""
	if stem == "raccoon_front":
		add = recipe.add.get("raccoon_front_body", "") + recipe.add.get("raccoon_front_head", "")
	else:
		add = recipe.add.get(stem, "")
	add = add.replace("@stripes", _stripes()).replace("@vest", vest)
	return svg.replace("</svg>", add + "</svg>") if add != "" else svg


## Burglar stripes, clipped to the vest the shirt takes the place of.
static func _stripes() -> String:
	var s := '<clipPath id="vest"><path d="@vest"/></clipPath><g clip-path="url(#vest)" fill="#22252E">'
	for y in [45, 51, 63]:
		s += '<rect x="10" y="%d" width="44" height="3"/>' % y
	return s + "</g>"


static func _import_params(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	return text.substr(text.find("[params]"))


static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
