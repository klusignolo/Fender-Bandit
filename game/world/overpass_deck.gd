class_name OverpassDeck
extends Node2D
## The bridge decks of a map's overpasses (#44), over the road beneath and the cars driving under them: the bridge
## road's asphalt and centre dashes, a kerb rail each side, and a shadow falling down-right onto the road below.

const OVERHANG := 16.0  # world px the deck runs past the road beneath on each side
const RAIL := 4.0  # world px: each side rail
const SHADOW_FALL := Vector2(8, 8)  # the deck stands higher than a vehicle, so its shadow falls further
const DASH := 12.0  # world px of centre dash, then as much gap

var _net: RoadNet


func _init(net: RoadNet) -> void:
	_net = net
	z_as_relative = false
	z_index = Art.Z_DECK


func _draw() -> void:
	for o in _net.overpasses:
		var u := o.over_dir
		var v := RoadNet.right_of(u)
		var half_len := Tuning.LW + Ground.KERB_W + OVERHANG  # along the bridge: across the road beneath
		var half_w := Tuning.LW + Ground.KERB_W  # across the bridge: its two lanes and kerbs
		draw_colored_polygon(_quad(o.centre + SHADOW_FALL, u, v, half_len, half_w + RAIL), Art.SHADOW)
		draw_colored_polygon(_quad(o.centre, u, v, half_len, half_w + RAIL), Art.INK)
		draw_colored_polygon(_quad(o.centre, u, v, half_len, half_w), Ground.KERB)
		draw_colored_polygon(_quad(o.centre, u, v, half_len, Tuning.LW), Ground.ASPHALT)
		var s := -half_len
		while s < half_len:
			draw_line(o.centre + u * s, o.centre + u * minf(s + DASH, half_len), Ground.MARKING, 2.0)
			s += DASH * 2.0


# A rectangle centred on `c`, `half_len` along `u` and `half_w` along `v` each way.
static func _quad(c: Vector2, u: Vector2, v: Vector2, half_len: float, half_w: float) -> PackedVector2Array:
	return PackedVector2Array([c - u * half_len - v * half_w, c + u * half_len - v * half_w, c + u * half_len + v * half_w, c - u * half_len + v * half_w])
