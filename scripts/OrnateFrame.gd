## OrnateFrame.gd — the decorative "character plate" frame drawn over each
## roster card's portrait window + nameplate (round 13). Fully procedural, no
## art needed: beveled corners each set with a small faceted gem stud, a
## doubled border (her accent color outside, a warm gold hairline inset just
## inside it), a crest gem riding the middle of the top edge, and a gem-studded
## divider across the seam between her portrait and her nameplate.
##
## Drawn as an overlay ON TOP of the plate's content (it's added as the
## plate's last child). The little corner triangles outside each bevel are
## painted in the card's own background color — that's what lets a plain
## rectangular clip_contents window read as a beveled frame without needing
## any alpha-mask / clip_children support from the Compatibility renderer.
class_name OrnateFrame
extends Control

const GOLD := Color("#E2B659")
const GOLD_DEEP := Color("#9A7630")

## Her accent color — the outer border, crest wings and gem centers.
var accent := Color("#FF6F91"):
	set(v):
		accent = v
		queue_redraw()

## Must match whatever the plate sits on (the card's fill), so the masked
## corner triangles disappear into it.
var mask_color := Color("#FFF6F0"):
	set(v):
		mask_color = v
		queue_redraw()

## Size of each corner bevel, in px.
var chamfer := 16.0:
	set(v):
		chamfer = v
		queue_redraw()

## Local y of the portrait/nameplate seam, or < 0 for no divider.
var divider_y := -1.0:
	set(v):
		divider_y = v
		queue_redraw()

## The roster's currently selected girl gets a heavier border, a soft outer
## glow and a slightly bigger crest gem.
var selected := false:
	set(v):
		if v == selected:
			return
		selected = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := chamfer
	if w < c * 3.0 or h < c * 3.0:
		return

	# 1. Mask the rectangular content outside each bevel.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(c, 0), Vector2(0, c)]), mask_color)
	draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, c), Vector2(w - c, 0)]), mask_color)
	draw_colored_polygon(PackedVector2Array([Vector2(w, h), Vector2(w - c, h), Vector2(w, h - c)]), mask_color)
	draw_colored_polygon(PackedVector2Array([Vector2(0, h), Vector2(0, h - c), Vector2(c, h)]), mask_color)

	var band := accent.darkened(0.08)

	# 2. Selected: a soft glow hugging the outside of the frame.
	if selected:
		draw_polyline(_bevel(Rect2(-3.0, -3.0, w + 6.0, h + 6.0), c + 1.2),
			Color(accent.r, accent.g, accent.b, 0.4), 5.0, true)

	# 3. The molding: a band of her color with a dark outer edge and a light
	#    inner edge (reads as a raised, beveled frame rather than a flat
	#    line), then a gold hairline set just inside it.
	var bw := 6.0 if selected else 5.0
	draw_polyline(_bevel(_inset(bw * 0.5), _bev(bw * 0.5)), band, bw, true)
	draw_polyline(_bevel(_inset(0.5), _bev(0.5)), accent.darkened(0.4), 1.0, true)
	draw_polyline(_bevel(_inset(bw - 0.5), _bev(bw - 0.5)), accent.lightened(0.4), 1.0, true)
	var gi := bw + 2.5
	draw_polyline(_bevel(_inset(gi), _bev(gi)), GOLD, 1.3, true)

	# 4. Gold filigree tucked into each corner, inside the hairline: a short
	#    bracket along both edges (parallel to the frame's own bevel),
	#    finished with a dot.
	var fi := gi + 3.5
	var arm := 15.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var sx: float = 1.0 if corner.x == 0.0 else -1.0
		var sy: float = 1.0 if corner.y == 0.0 else -1.0
		var ox: float = corner.x * w + sx * fi
		var oy: float = corner.y * h + sy * fi
		var k := _bev(fi)
		var a := Vector2(ox + sx * k, oy)
		var b := Vector2(ox, oy + sy * k)
		draw_line(a, a + Vector2(sx * arm, 0), GOLD, 1.3, true)
		draw_line(b, b + Vector2(0, sy * arm), GOLD, 1.3, true)
		draw_line(a, b, GOLD, 1.3, true)
		draw_circle(a + Vector2(sx * (arm + 2.5), 0), 1.6, GOLD)
		draw_circle(b + Vector2(0, sy * (arm + 2.5)), 1.6, GOLD)

	# 5. Divider across the portrait/nameplate seam.
	if divider_y > c and divider_y < h - c:
		var y := divider_y
		draw_line(Vector2(bw, y), Vector2(w - bw, y), band, 3.0, true)
		draw_line(Vector2(bw, y + 2.4), Vector2(w - bw, y + 2.4), GOLD, 1.2, true)
		for dx in [-15.0, 15.0]:
			_gem(Vector2(w * 0.5 + dx, y + 0.8), 3.2)
		_gem(Vector2(w * 0.5, y + 0.8), 6.0)

	# 6. A gem set into the middle of each beveled corner of the band.
	var q := (bw + _bev(bw * 0.5)) * 0.5
	for p in [Vector2(q, q), Vector2(w - q, q), Vector2(w - q, h - q), Vector2(q, h - q)]:
		_gem(p, 5.5)

	# 7. Crest: a large center gem riding the top edge, flanked by two small
	#    ones and a pair of gold dots.
	var cx := w * 0.5
	for sgn in [-1.0, 1.0]:
		_gem(Vector2(cx + sgn * 17.0, 2.5), 3.6)
		draw_circle(Vector2(cx + sgn * 27.0, 2.5), 1.8, GOLD)
	_gem(Vector2(cx, 2.5), 9.5 if selected else 8.5)


## A faceted diamond-cut gem in a gold setting: dark gold rim, her accent
## color inside, a lighter upper-left facet, a mid upper-right facet, and a
## white glint.
func _gem(ctr: Vector2, r: float) -> void:
	draw_colored_polygon(_diamond(ctr, r), GOLD_DEEP)
	var ri := r - 1.4
	var base := accent.darkened(0.06)
	draw_colored_polygon(_diamond(ctr, ri), base)
	var top := ctr + Vector2(0, -ri)
	var right := ctr + Vector2(ri, 0)
	var left := ctr + Vector2(-ri, 0)
	draw_colored_polygon(PackedVector2Array([top, ctr, left]), base.lightened(0.45))
	draw_colored_polygon(PackedVector2Array([top, right, ctr]), base.lightened(0.18))
	draw_circle(ctr + Vector2(-ri * 0.28, -ri * 0.42), maxf(0.9, ri * 0.17), Color(1, 1, 1, 0.9))


## This control's rect, shrunk by `d` on every side.
func _inset(d: float) -> Rect2:
	return Rect2(d, d, size.x - d * 2.0, size.y - d * 2.0)


## Bevel size for an outline inset by `d`, so it runs exactly parallel to
## the outer bevel (a 45° cut moves in by d·(2 − √2) per d of inset).
func _bev(d: float) -> float:
	return maxf(1.0, chamfer - d * (2.0 - sqrt(2.0)))


static func _diamond(ctr: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([
		ctr + Vector2(0, -r), ctr + Vector2(r, 0), ctr + Vector2(0, r), ctr + Vector2(-r, 0)])


## Closed outline of a rect with its four corners beveled by `c`.
static func _bevel(r: Rect2, c: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c),
		Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1),
		Vector2(x0, y1 - c), Vector2(x0, y0 + c), Vector2(x0 + c, y0)])
