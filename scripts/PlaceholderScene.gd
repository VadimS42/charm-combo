## PlaceholderScene.gd — a procedural stand-in for a character's location
## background (round 13), used wherever her real art at
## res://art/backgrounds/<bg>.png doesn't exist yet: behind the roster's
## flying-camera backdrop, and inside each roster card's portrait window.
##
## A deep vertical gradient in her accent color, a few soft diagonal light
## shafts, a pool of light near the floor and a scatter of out-of-focus
## "bokeh" circles. Abstract on purpose (it's a placeholder, and it's tagged
## as one wherever it's shown), but with enough depth and detail that a slow
## camera drift across it reads as moving through a place rather than a flat
## color swatch sliding around. Seeded from her id, so each girl's stand-in
## looks identical everywhere it appears. Everything scales with the
## control's height, so the same scene works at full-screen and card size.
##
## motes_only = true instead draws just a sparse field of small bright
## floating particles on a transparent background — the roster layers one of
## these over the scene and drifts it farther than the scene itself, for a
## cheap bit of parallax depth (it rides over real background art too).
class_name PlaceholderScene
extends Control

var accent := Color("#FF6F91")
var seed_value := 1
var motes_only := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func setup(p_accent: Color, p_seed: int, p_motes_only: bool = false) -> PlaceholderScene:
	accent = p_accent
	seed_value = p_seed
	motes_only = p_motes_only
	queue_redraw()
	return self


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Designed against an 800px-tall screen; everything size-like scales by this.
	var k := h / 800.0

	if motes_only:
		_draw_motes(rng, w, h, k)
		return

	# 1. Sky-to-floor gradient (3 stops, as two quads).
	var top := accent.darkened(0.62).lerp(Color("#150F22"), 0.35)
	var mid := accent.darkened(0.3)
	var low := accent.darkened(0.52).lerp(Color("#1A1224"), 0.2)
	var m := h * 0.58
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, m), Vector2(0, m)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, m), Vector2(w, m), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([mid, mid, low, low]))

	# 2. A soft pool of light on the "floor".
	var pool := accent.lightened(0.3)
	for i in range(6):
		var t := float(i) / 6.0
		_ellipse(Vector2(w * 0.5, h * 0.9),
			Vector2(w * (0.55 - t * 0.35), h * (0.2 - t * 0.12)),
			Color(pool.r, pool.g, pool.b, 0.05))

	# 3. Diagonal light shafts falling from the top edge.
	for i in range(4):
		var x0 := w * rng.randf_range(-0.1, 0.6)
		var top_w := w * rng.randf_range(0.025, 0.07)
		var slant := w * rng.randf_range(0.16, 0.3)
		var bot_w := top_w * rng.randf_range(2.5, 4.0)
		var a := rng.randf_range(0.05, 0.1)
		draw_polygon(
			PackedVector2Array([Vector2(x0, -4), Vector2(x0 + top_w, -4),
				Vector2(x0 + slant + bot_w, h * 0.95), Vector2(x0 + slant, h * 0.95)]),
			PackedColorArray([Color(1, 1, 1, a), Color(1, 1, 1, a), Color(1, 1, 1, 0), Color(1, 1, 1, 0)]))

	# 4. Out-of-focus bokeh.
	var warm := Color("#FFD9A0")
	var soft := accent.lightened(0.55)
	for i in range(42):
		var p := Vector2(rng.randf() * w, rng.randf() * h * 0.92)
		var r := rng.randf_range(10.0, 72.0) * k
		var pick := rng.randf()
		var col: Color = soft if pick < 0.5 else (Color.WHITE if pick < 0.8 else warm)
		_soft_circle(p, r, col, rng.randf_range(0.035, 0.12))


func _draw_motes(rng: RandomNumberGenerator, w: float, h: float, k: float) -> void:
	for i in range(int(clampf(w * h / 36000.0, 12.0, 60.0))):
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var r := rng.randf_range(1.2, 3.4) * maxf(k, 0.6)
		var a := rng.randf_range(0.25, 0.6)
		draw_circle(p, r * 2.6, Color(1, 1, 1, a * 0.12))
		draw_circle(p, r, Color(1, 1, 1, a))


## Three stacked circles of rising opacity — a cheap soft-edged disc.
func _soft_circle(p: Vector2, r: float, col: Color, a: float) -> void:
	draw_circle(p, r, Color(col.r, col.g, col.b, a * 0.55))
	draw_circle(p, r * 0.78, Color(col.r, col.g, col.b, a * 0.7))
	draw_circle(p, r * 0.5, Color(col.r, col.g, col.b, a))


func _ellipse(ctr: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(40):
		var ang := TAU * float(i) / 40.0
		pts.append(ctr + Vector2(cos(ang) * radii.x, sin(ang) * radii.y))
	draw_colored_polygon(pts, col)
