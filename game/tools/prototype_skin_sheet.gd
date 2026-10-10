extends SceneTree
## PROTOTYPE (prototype/raccoon-skins): renders every PrototypeSkins look in the front, side and back views at rest,
## at 3× and at 1×, on the road grey, to docs/art/prototype-raccoon-skins.png.
##   godot --headless --path game -s tools/prototype_skin_sheet.gd

const BIG := 3
const CELL := Vector2i(64 * BIG + 24, 84 * BIG + 24)
const SMALL_ROW := 84 + 24


func _initialize() -> void:
	var views := [Raccoon.View.FRONT, Raccoon.View.RIGHT, Raccoon.View.BACK]
	var n := PrototypeSkins.SKINS.size()
	var sheet := Image.create_empty(CELL.x * views.size() + 64 * 3 + 80, CELL.y * n, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#5B6170"))
	for i in n:
		for vi in views.size():
			var img := Image.create_empty(64, 84, false, Image.FORMAT_RGBA8)
			for p: Array in RaccoonRig._PARTS[views[vi]]:
				if p[0] == &"blink":
					continue
				var part := PrototypeSkins.texture(p[1], i).get_image()
				part.convert(Image.FORMAT_RGBA8)
				img.blend_rect(part, Rect2i(0, 0, 64, 84), Vector2i.ZERO)
			var big := img.duplicate() as Image
			big.resize(64 * BIG, 84 * BIG, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(CELL.x * vi + 12, CELL.y * i + 12))
			var small := img.duplicate() as Image
			small.resize(29, 38, Image.INTERPOLATE_LANCZOS)  # about the 0.45 zoom floor
			sheet.blend_rect(small, Rect2i(0, 0, 29, 38), Vector2i(CELL.x * views.size() + 20 + vi * 64, CELL.y * i + 110))
		print(PrototypeSkins.name_of(i))
	var out := ProjectSettings.globalize_path("res://").path_join("../docs/art/prototype-raccoon-skins.png")
	sheet.save_png(out)
	print("wrote ", out)
	quit()
