class_name City
## The City plan (#31): one hand-authored plan of up to six crossings, in the order they attach. They sit on a
## 3×2 grid LINK apart, every neighbour linked, so the roads make city blocks. RoadNet builds the first n.
##
##     E ─── A ─── B        A: stage 1    B: stage 4    C: stage 9 (a T: no south arm)
##     │     │     │        D: stage 13   E: stage 17 (a 5-way: a fifth arm off to the north-west)
##     F ─── C ─── D        F: stage 21
##
## For now RoadNet builds every crossing as a plain 4-way from the axis arms; the T and the 5-way come in #32.

## Each crossing's centre, in LINKs from the first, in attach order: A, B, C, D, E, F.
const CENTRES: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 0), Vector2(-1, 1)]
## Each crossing's arms, as the angles in degrees the roads leave it at: 0 is east, 90 south (screen y points down).
## Four arms make a 4-way, three a T, five a 5-way.
const ARMS: Array[Array] = [
	[0, 90, 180, 270],
	[0, 90, 180, 270],
	[0, 180, 270],  # C: a T, no south arm
	[0, 90, 180, 270],
	[0, 90, 180, 225, 270],  # E: a 5-way, its fifth arm off to the north-west
	[0, 90, 180, 270],
]
## Pairs of crossings joined by a road. A link is on the map once both its crossings are.
const LINKS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(0, 4), Vector2i(4, 5), Vector2i(2, 5)]


## Where crossing k sits, in world px.
static func centre(k: int) -> Vector2:
	return CENTRES[k] * Tuning.LINK


## The crossing linked to crossing x in direction `dir`, among the first n to attach, or -1.
static func linked(x: int, dir: Vector2, n: int) -> int:
	for l in LINKS:
		if l.x >= n or l.y >= n or (l.x != x and l.y != x):
			continue
		var other := l.y if l.x == x else l.x
		if (centre(other) - centre(x)).normalized().is_equal_approx(dir):
			return other
	return -1
