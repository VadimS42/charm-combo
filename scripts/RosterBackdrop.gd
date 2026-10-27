## RosterBackdrop.gd — the roster's full-screen "camera" slowly flying over
## whichever girl is currently selected (round 13).
##
## Each girl gets a "shot": her real location art the moment
## res://art/backgrounds/<bg>.png exists (only Marina's does so far),
## otherwise her PlaceholderScene — zoomed in past the screen edges so there's
## room to move, then drifted and gently re-zoomed through a looping path of
## waypoints, Ken Burns style. A sparse layer of floating motes rides on top
## and drifts farther than the scene itself, for a little parallax depth.
## Switching girls crossfades to her shot; opening one plays a quick zoom-in
## (zoom_in()) that RosterScreen hands off from. With Reduce Motion on, the
## same zoomed framing is simply held still and switches are instant.
##
## Every tween here is created from (bound to) the node it animates, so the
## whole thing stops on its own the moment clear_screen() frees the roster —
## nothing here ever awaits, so nothing can resume on a dead screen.
class_name RosterBackdrop
extends Control

const CROSSFADE_SEC := 0.7

## Camera waypoints: [zoom, pan_x, pan_y]. Pan is a fraction of the safe
## margin that zoom leaves past each screen edge — ±1.0 would put the image
## edge exactly on the screen edge; these stay within ±0.8. Zoom and pan are
## tweened with the same easing, so every in-between frame is a blend of two
## safe frames and stays safe too (no edge ever slides into view).
const WAYPOINTS := [
	[1.16, -0.75, 0.25],
	[1.26, 0.6, -0.55],
	[1.2, 0.15, 0.75],
	[1.3, -0.55, -0.6],
	[1.18, 0.8, 0.35],
]

## How much farther than the scene the motes layer drifts (parallax), and
## the extra canvas it gets past each edge so that drift never runs out.
const MOTES_PARALLAX := 1.8
const MOTES_BLEED := Vector2(320, 220)

## Id of the girl whose shot is (or is becoming) the visible one.
var current_id := ""
var _current: Control = null
var _fade: Tween = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	# Dark base under everything, so a crossfade never flashes the page color.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17111F"))


static func _reduce_motion() -> bool:
	return bool(GameState.settings.get("reduce_motion", false))


## Switch the camera to this girl's shot — a crossfade, unless `instant`,
## Reduce Motion, or there's nothing on screen yet.
func show_character(ch: Dictionary, instant: bool = false) -> void:
	var id := String(ch.get("id", ""))
	if id == current_id and _current != null:
		return
	current_id = id
	# Settle any crossfade still in flight first, so the new shot always fades
	# in over one fully opaque shot (never over a half-transparent stack).
	if _fade and _fade.is_valid():
		_fade.kill()
	for child in get_children():
		if child != _current:
			child.queue_free()
	if _current:
		_current.modulate.a = 1.0

	var shot := _make_shot(ch)
	add_child(shot)
	var old := _current
	_current = shot
	if old == null or instant or _reduce_motion():
		if old:
			old.queue_free()
	else:
		shot.modulate.a = 0.0
		_fade = shot.create_tween()
		_fade.tween_property(shot, "modulate:a", 1.0, CROSSFADE_SEC) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_fade.tween_callback(func():
			if is_instance_valid(old):
				old.queue_free()
		)
	# Deferred: the camera's pan distances depend on its laid-out size.
	_start_camera.call_deferred(shot)


## Quick zoom-in "punch" on the current shot, played when a girl is opened,
## right before RosterScreen hands off to her story. Returns the tween (bound
## to the camera node, so it dies with the screen) for the caller to chain
## onto, or null under Reduce Motion / with nothing on screen.
func zoom_in(duration: float = 0.5) -> Tween:
	if _current == null or _reduce_motion():
		return null
	var cam: Control = _current.get_node("Camera")
	# From here on nothing else may move this camera: a _start_camera() still
	# deferred from a just-made switch, or the next leg of the drift, would
	# otherwise tween its scale at the same time as the zoom (both check this).
	_current.set_meta("zooming", true)
	# has_meta() first: get_meta() with a null default logs an error in Godot
	# 4.3 when the key is missing (no leg has started yet right after a switch).
	if _current.has_meta("leg"):
		var leg = _current.get_meta("leg")
		if leg is Tween and leg.is_valid():
			leg.kill()
	if _fade and _fade.is_valid():
		_fade.kill()
	_current.modulate.a = 1.0
	var tw := cam.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(cam, "scale", cam.scale * 1.25, duration)
	return tw


func _make_shot(ch: Dictionary) -> Control:
	var id := String(ch.get("id", ""))
	var accent := Color(String(ch.get("c", "#FF6F91")))
	var seed_value := hash(id)

	var shot := Control.new()
	shot.name = "Shot_" + id
	shot.set_anchors_preset(Control.PRESET_FULL_RECT)
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The "camera" is really the scene layer itself: scaling it up about its
	# center and sliding it around is the same thing, on screen, as a camera
	# zooming and panning over a fixed scene.
	var cam := Control.new()
	cam.name = "Camera"
	cam.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cam.resized.connect(func(): cam.pivot_offset = cam.size * 0.5)
	shot.add_child(cam)

	var tex := ArtAssets.background_for(String(ch.get("bg", "")))
	if tex:
		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cam.add_child(img)
	else:
		var scene := PlaceholderScene.new().setup(accent, seed_value)
		scene.set_anchors_preset(Control.PRESET_FULL_RECT)
		cam.add_child(scene)

	var motes := PlaceholderScene.new().setup(accent, seed_value + 17, true)
	motes.name = "Motes"
	motes.anchor_right = 1.0
	motes.anchor_bottom = 1.0
	motes.offset_left = -MOTES_BLEED.x
	motes.offset_top = -MOTES_BLEED.y
	motes.offset_right = MOTES_BLEED.x
	motes.offset_bottom = MOTES_BLEED.y
	shot.add_child(motes)

	# Each girl starts at a different point on the path, so switching between
	# them never looks like the same camera move replayed.
	var start := absi(seed_value) % WAYPOINTS.size()
	var z: float = WAYPOINTS[start][0]
	cam.scale = Vector2(z, z)
	shot.set_meta("wp", start)
	return shot


func _start_camera(shot: Control) -> void:
	if not is_instance_valid(shot) or shot.is_queued_for_deletion():
		return
	var cam: Control = shot.get_node("Camera")
	var motes: Control = shot.get_node("Motes")
	var i: int = shot.get_meta("wp", 0)
	cam.pivot_offset = cam.size * 0.5
	var pan := _pan_for(WAYPOINTS[i], cam.size)
	cam.position = pan
	motes.position = pan * MOTES_PARALLAX - MOTES_BLEED
	if _reduce_motion() or shot.has_meta("zooming"):
		return
	_leg(shot, cam, motes, i + 1)


func _pan_for(wp: Array, sz: Vector2) -> Vector2:
	var z: float = wp[0]
	return Vector2(float(wp[1]) * (z - 1.0) * sz.x * 0.5, float(wp[2]) * (z - 1.0) * sz.y * 0.5)


## One slow leg of the camera path, then chain the next — a tween_callback
## rather than set_loops(), so each leg re-reads the current size and the
## Reduce Motion setting (the settings overlay can flip it mid-flight).
func _leg(shot: Control, cam: Control, motes: Control, i: int) -> void:
	if not is_instance_valid(cam) or not is_instance_valid(motes) or _reduce_motion():
		return
	if not is_instance_valid(shot) or shot.has_meta("zooming"):
		return
	var wp: Array = WAYPOINTS[i % WAYPOINTS.size()]
	var z: float = wp[0]
	var pan := _pan_for(wp, cam.size)
	var dur := 7.5 + float(i % 3) * 1.25
	var tw := cam.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "scale", Vector2(z, z), dur)
	tw.parallel().tween_property(cam, "position", pan, dur)
	tw.parallel().tween_property(motes, "position", pan * MOTES_PARALLAX - MOTES_BLEED, dur)
	tw.tween_callback(_leg.bind(shot, cam, motes, i + 1))
	shot.set_meta("leg", tw)
