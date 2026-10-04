class_name Art
extends RefCounted
## The first-pass sprites (#39) and the draw order, from docs/sprites.md. Every SVG is authored at AUTHORED× its world
## size, with a MARGIN of world px around the art for the outline, and imported with mipmaps; World draws with a Linear
## Mipmap filter, as the camera zooms out to the readability floor.

const AUTHORED := 2.0  # texture px per world px
const SCALE := 1.0 / AUTHORED  # a sprite's scale, to draw it at world size
const MARGIN := 2.0  # world px of outline around every vehicle's footprint
const SHADOW_FALL := Vector2(3, 3)  # world px a shadow falls down-right of its sprite, light from the top-left
const SHADOW := Color("#0E1424", 0.45)  # `shadow`
const INK := Color("#1B2340")  # `ink`

## Draw order, bottom to top, as absolute z indices.
const Z_GROUND := -10  # ground, blocks, roads and road decals
const Z_DECAL := -9  # stop lines, over the roads
const Z_SHADOW := -8  # vehicle and upright shadows
const Z_VEHICLE := 0
const Z_UPRIGHT := 1  # the Raccoon and the Light poles, Y-sorted
const Z_CUE := 5  # floating cues: upright, never rotated with their vehicle
const Z_BURST := 10  # Crash bursts

const _VEHICLES := {
	Car.Kind.CAR: {
		"body": preload("res://art/car_body.svg"),
		"details": preload("res://art/car_details.svg"),
		"wreck": preload("res://art/car_wreck.svg"),
		"shadow": preload("res://art/car_shadow.svg"),
	},
	Car.Kind.MOTORCYCLE: {
		"body": preload("res://art/moto_body.svg"),  # the rider's helmet
		"details": preload("res://art/moto_details.svg"),
		"wreck": preload("res://art/moto_wreck.svg"),
		"shadow": preload("res://art/moto_shadow.svg"),
	},
	Car.Kind.SEMI: {
		"body": preload("res://art/semi_body.svg"),  # the trailer; the cab is in the details
		"details": preload("res://art/semi_details.svg"),
		"wreck": preload("res://art/semi_wreck.svg"),
		"shadow": preload("res://art/semi_shadow.svg"),
	},
}

const RACCOON_FRONT := preload("res://art/raccoon_front.svg")
const RACCOON_BACK := preload("res://art/raccoon_back.svg")
const RACCOON_SIDE := preload("res://art/raccoon_side.svg")  # facing right
const RACCOON_FEET := Vector2(32, 80)  # texture px of the feet in each Raccoon view: its anchor

const LIGHT_POLE := preload("res://art/light_pole.svg")
const POLE_BASE := Vector2(14, 80)  # texture px of the pole's base: its anchor
const POLE_LAMPS: Array[float] = [11.0, 24.0, 37.0]  # texture px down to the red, yellow and green lamps' centres
const POLE_LAMP_R := 5.0  # texture px

const CUE_TURNER := preload("res://art/cue_turner.svg")
const CUE_TURNER_ARROW := preload("res://art/cue_turner_arrow.svg")  # points +x
const CUE_HONK := preload("res://art/cue_honk.svg")
const CUE_BLOW := preload("res://art/cue_blow.svg")
const CUE_SWELL := preload("res://art/cue_swell.svg")  # one chevron, pointing +x
const CRASH_BURST := preload("res://art/crash_burst.svg")

const ROOFS: Array[Texture2D] = [
	preload("res://art/roof_a.svg"),
	preload("res://art/roof_b.svg"),
	preload("res://art/roof_c.svg"),
	preload("res://art/roof_d.svg"),
	preload("res://art/roof_e.svg"),
]


## A vehicle kind's layers: "body" (white, tinted in Godot), "details" (never tinted), "wreck" (the details as Wreckage)
## and "shadow" (its silhouette, drawn in SHADOW).
static func vehicle(kind: Car.Kind) -> Dictionary:
	return _VEHICLES[kind]


## A world-size sprite of `tex`, centred on its node.
static func sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2(SCALE, SCALE)
	return s
