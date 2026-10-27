## FrameAnimation.gd — plays a character's idle animation (a folder of
## transparent PNG frames) as a looping sprite (round 14; first used for
## Marina's swim loop on the right of her puzzle chapter).
##
## It's just a TextureRect whose texture is swapped each tick, so it lays out
## and scales exactly like the static portrait TextureRect it replaces. The
## frame ORDER comes from a "sequence" playlist (see ArtAssets.idle_animation()
## and the art/characters/<id>/idle/idle.json it reads): one full cycle of
## frame indices, stepped through at `fps` and wrapped. Marina's clip doesn't
## end in the pose it starts in, so her baked sequence plays it forward and
## then back with eased turnarounds — a straight loop would visibly snap.
##
## Reduce Motion holds the first frame of the cycle still (checked every
## tick, so flipping it in the Settings overlay mid-chapter takes effect
## immediately).
class_name FrameAnimation
extends TextureRect

var frames: Array = []
var sequence := PackedInt32Array()
var fps := 24.0
## Position in `sequence` currently on screen.
var cursor := 0
var _accum := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


## `anim` is ArtAssets.idle_animation()'s result: {frames, sequence, fps}.
func setup(anim: Dictionary) -> FrameAnimation:
	frames = anim.get("frames", [])
	sequence = anim.get("sequence", PackedInt32Array())
	fps = maxf(1.0, float(anim.get("fps", 24.0)))
	cursor = 0
	_accum = 0.0
	_show()
	return self


func _process(delta: float) -> void:
	if frames.is_empty() or sequence.size() < 2:
		return
	if GameState.settings.get("reduce_motion", false):
		if cursor != 0:
			cursor = 0
			_show()
		return
	_accum += delta
	var step := 1.0 / fps
	if _accum < step:
		return
	# Catch up by whole frames after a hitch rather than playing slow-motion,
	# but don't spin through a huge backlog (e.g. after the window was hidden).
	var n := mini(int(_accum / step), sequence.size())
	_accum = minf(_accum - float(n) * step, step)
	cursor = (cursor + n) % sequence.size()
	_show()


func _show() -> void:
	if frames.is_empty():
		texture = null
		return
	var idx := 0
	if not sequence.is_empty():
		idx = clampi(sequence[cursor % sequence.size()], 0, frames.size() - 1)
	texture = frames[idx]
