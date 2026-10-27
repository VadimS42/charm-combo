## LeafDrift.gd — a few leaves drifting down from her tree, over her figure
## in her puzzle chapters (round 20, Hazel: live.json "ambient": "leaves").
## Drawn shapes, no art. Never more than a handful at once, slow, and gone
## with Reduce Motion — atmosphere, not something to watch.
class_name LeafDrift
extends Control

var colors: Array = [Color("8DB46E"), Color("B7C982"), Color("6E8F4A"), Color("C9D27A")]
var max_leaves := 4

var _leaves: Array = []
var _wait := 0.6
var _shape := PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# One leaf, 1 px long, pointed at both ends, along +x.
	var top: Array = []
	var bottom: Array = []
	var n := 10
	for i in range(n + 1):
		var t := float(i) / float(n)
		var half_w := 0.24 * pow(sin(PI * t), 0.85) * (1.0 - 0.25 * t)
		top.append(Vector2(t - 0.5, -half_w))
		bottom.push_front(Vector2(t - 0.5, half_w))
	for p in top + bottom:
		_shape.append(p)


func _process(delta: float) -> void:
	if GameState.settings.get("reduce_motion", false):
		if not _leaves.is_empty():
			_leaves.clear()
			queue_redraw()
		return
	delta = minf(delta, 0.1)
	_wait -= delta
	if _wait <= 0.0 and _leaves.size() < max_leaves and size.x > 0.0:
		_wait = randf_range(1.8, 3.6)
		_spawn()
	for i in range(_leaves.size() - 1, -1, -1):
		var l: Dictionary = _leaves[i]
		l.age += delta
		l.y += l.vy * delta
		if l.age >= l.life or l.y > size.y * 0.92:
			_leaves.remove_at(i)
	queue_redraw()


func _spawn() -> void:
	var s := size.y / 575.0  # sizes below are for her usual 575 px height
	_leaves.append({
		# mostly either side of her rather than across her
		"x0": (randf_range(0.04, 0.34) if randf() < 0.55 else randf_range(0.72, 0.96)) * size.x,
		"y": randf_range(-0.02, 0.14) * size.y,
		"vy": randf_range(26.0, 40.0) * s,
		"amp": randf_range(14.0, 30.0) * s,
		"freq": randf_range(0.9, 1.5),
		"ph": randf_range(0.0, TAU),
		"spin": randf_range(1.2, 2.6),
		"len": randf_range(15.0, 21.0) * s,
		"col": colors[randi() % colors.size()],
		"age": 0.0,
		"life": randf_range(9.0, 13.0),
	})


func _draw() -> void:
	for l in _leaves:
		var a: float = l.age
		var alpha := clampf(a / 0.8, 0.0, 1.0) * clampf((l.life - a) / 1.5, 0.0, 1.0)
		alpha *= 1.0 - smoothstep(0.7, 0.92, l.y / maxf(1.0, size.y))
		if alpha <= 0.01:
			continue
		var sw: float = sin(l.ph + l.freq * a)
		var pos := Vector2(l.x0 + l.amp * sw, l.y)
		# tilts into each swing, and flutters (turning edge-on now and then)
		var rot: float = 0.5 + 0.7 * cos(l.ph + l.freq * a)
		var flutter: float = 0.35 + 0.65 * absf(cos(l.spin * a))
		draw_set_transform(pos, rot, Vector2(l.len, l.len * flutter))
		var c: Color = l.col
		c.a = alpha * 0.92
		draw_colored_polygon(_shape, c)
		# soft edge + midrib (draw_colored_polygon itself isn't antialiased)
		var edge := c
		edge.a *= 0.6
		var ring := _shape.duplicate()
		ring.append(_shape[0])
		draw_polyline(ring, edge, 1.0 / l.len, true)
		var rib: Color = c.darkened(0.3)
		rib.a = alpha * 0.55
		draw_line(Vector2(-0.5, 0.0), Vector2(0.42, 0.0), rib, 0.9 / l.len, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
