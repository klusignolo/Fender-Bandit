class_name PrototypeSkins
## PROTOTYPE (branch prototype/raccoon-skins, not for main): alternative Raccoon looks, to compare in the game.
## F7 in a Run cycles them; tools/prototype_skin_sheet.gd renders a side-by-side sheet. Each skin rewrites the rig's
## SVG part sources as text: a colour swap, then costume shapes injected on the part's shared 64×84 canvas, so the
## rig, pivots and animations are untouched. The SVG sources are read from res://, so this runs from the project,
## not from an export.

const FUR := "#8C93A3"
const VEST := "#FF7A1A"
const STRIPE := "#EEF1F6"
const INK := "#1B2340"

static var current := _from_args()  # --skin=N picks one at boot, for screenshots

## name, colour swaps, and per-file injections: file stem → SVG fragment appended inside <svg>, in canvas px.
## "@vest" in a fragment is replaced by the part's vest path data, for clipping shapes to the vest.
static var SKINS: Array = [
	{"name": "A · Crossing guard (current)", "swap": {}, "add": {}},
	{
		"name": "B · Cat burglar",
		"swap": {VEST: "#F4F1E8", STRIPE: "#22252E"},
		"add": {
			"raccoon_front_body": _stripes(),
			"raccoon_side_body": _stripes(),
			"raccoon_back_body": _stripes() + '<path d="M38,50 C46,46 54,52 52,62 C50,70 38,70 36,62 C34,56 34,52 38,50 Z" fill="#C9B28A" stroke="#1B2340" stroke-width="2.5"/><path d="M37,51 L40,47 L43,50" fill="none" stroke="#1B2340" stroke-width="2"/><text x="40" y="64" font-size="9" font-weight="bold" fill="#1B2340">$</text>',
			"raccoon_front_head": '<path d="M14,23 C13,7 51,7 50,23 Z" fill="#22252E" stroke="#1B2340" stroke-width="2.5"/><path d="M13,18 L51,18 L51,23 L13,23 Z" fill="#363B4D" stroke="#1B2340" stroke-width="2"/>',
			"raccoon_back_head": '<path d="M14,24 C13,7 51,7 50,24 Z" fill="#22252E" stroke="#1B2340" stroke-width="2.5"/><path d="M13,19 L51,19 L51,24 L13,24 Z" fill="#363B4D" stroke="#1B2340" stroke-width="2"/>',
			"raccoon_side_head": '<path d="M16,25 C14,10 32,5 44,15 L44,22 Z" fill="#22252E" stroke="#1B2340" stroke-width="2.5"/><path d="M15,21 L45,18 L45,23 L16,26 Z" fill="#363B4D" stroke="#1B2340" stroke-width="2"/>',
		},
	},
	{
		"name": "C · Traffic cop",
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
	{
		"name": "D · Trash panda",
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
]


static func _stripes() -> String:
	var s := '<clipPath id="v"><path d="@vest"/></clipPath><g clip-path="url(#v)" fill="#22252E">'
	for y in [45, 51, 63]:
		s += '<rect x="10" y="%d" width="44" height="3"/>' % y
	return s + "</g>"


static func _from_args() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skin="):
			return int(a.get_slice("=", 1))
	return 0


static func name_of(i: int) -> String:
	return SKINS[i]["name"]


## The texture for one rig part under skin `i`, or `tex` itself for the current look.
static func texture(tex: Texture2D, i: int) -> Texture2D:
	if i == 0 or tex.resource_path == "":
		return tex
	var path := tex.resource_path
	var svg := FileAccess.get_file_as_string(path)
	var skin: Dictionary = SKINS[i]
	var vest := ""
	var m := RegEx.create_from_string('d="([^"]+)" fill="%s"' % VEST).search(svg)
	if m:
		vest = m.get_string(1)
	for from: String in skin["swap"]:
		svg = svg.replace(from, skin["swap"][from])
	var add: String = skin["add"].get(path.get_file().get_basename(), "")
	if add != "":
		svg = svg.replace("</svg>", add.replace("@vest", vest) + "</svg>")
	var img := Image.new()
	img.load_svg_from_string(svg, 1.0)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
