## LiveSprite.gd — a character's main sprite, alive (round 20; first Hazel on
## her tree, on the right of her puzzle chapters).
##
## Instead of a flipbook of frames (Marina's swim loop, FrameAnimation.gd),
## this is ONE picture cut into layers (ArtAssets.live_rig(): base, hair,
## mask, blink patches) and moved by live_sprite.gdshader: she breathes, her
## hanging hair sways in a slow wave that runs down the strands, her head
## drifts a touch, and she blinks now and then. The motions run at unrelated
## speeds, so it never visibly loops, and at rest she is exactly the drawn
## art (crisp at any window size, and it works in the browser build too).
##
## Reactions (react(), from PuzzleScreen) play on the rig instead of
## squashing the whole picture, so her tree stays put: a perk-up with a hair
## swish for good moves, a sigh for sad, a flustered head shake with a red
## flash for the cursed gem.
##
## Reduce Motion holds her still, eyes open (checked every frame, so the
## Settings toggle takes effect mid-chapter).
class_name LiveSprite
extends TextureRect

const SHADER := preload("res://scripts/live_sprite.gdshader")

## Motion settings; live.json beside the rig overrides any of them.
var breath_px := 2.4      # shoulders rise this far (sprite px) on each breath
var breath_sec := 4.6     # one breath, in and out
var sway_px := 5.5        # hair tips swing this far either way
var sway_sec := 5.8       # one full swing
var head_px := 1.0        # head drifts this far either way
var head_sec := 7.7
var blink_every := Vector2(2.2, 5.5)   # seconds between blinks (random)

var _mat: ShaderMaterial
var _t := 0.0
var _still := false
# blinking
var _has_blink := false
var _blink_wait := 1.5
var _blink_t := -1.0       # time into the current blink; < 0 = eyes open
var _double_next := false
# reactions
var _hop := 0.0            # extra rise (px), a spring
var _hop_v := 0.0
var _sigh_t := -1.0
var _shake_t := -1.0
var _swish_t := -1.0
var _swish_amp := 0.0
var _flash_tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Shown smaller than drawn: mipmaps keep the moving hair lines from
	# shimmering.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


## `rig` is ArtAssets.live_rig()'s result: {base, hair, mask, blink, config}.
func setup(rig: Dictionary) -> LiveSprite:
	texture = rig.base
	var cfg: Dictionary = rig.get("config", {})
	breath_px = float(cfg.get("breath_px", breath_px))
	breath_sec = maxf(0.5, float(cfg.get("breath_sec", breath_sec)))
	sway_px = float(cfg.get("sway_px", sway_px))
	sway_sec = maxf(0.5, float(cfg.get("sway_sec", sway_sec)))
	head_px = float(cfg.get("head_px", head_px))
	head_sec = maxf(0.5, float(cfg.get("head_sec", head_sec)))
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("hair_tex", rig.hair)
	_mat.set_shader_parameter("mask_tex", rig.mask)
	_mat.set_shader_parameter("hair_root_y", float(cfg.get("hair_root_y", 128.0)))
	_mat.set_shader_parameter("hair_tip_y", float(cfg.get("hair_tip_y", 610.0)))
	_mat.set_shader_parameter("wave_k", float(cfg.get("wave_k", 0.009)))
	var br: Array = cfg.get("blink_rect", [])
	_has_blink = rig.get("blink") != null and br.size() == 4
	if _has_blink:
		_mat.set_shader_parameter("blink_tex", rig.blink)
		_mat.set_shader_parameter("blink_rect", Vector4(float(br[0]), float(br[1]), float(br[2]), float(br[3])))
		_mat.set_shader_parameter("blink_frames", float(cfg.get("blink_frames", 2)))
	material = _mat
	# Start somewhere mid-cycle, so two visits don't open on the same pose.
	_t = randf_range(0.0, 60.0)
	_blink_wait = randf_range(0.8, 2.5)
	_apply()
	return self


func _process(delta: float) -> void:
	if _mat == null:
		return
	if GameState.settings.get("reduce_motion", false):
		if not _still:
			_still = true
			_blink_t = -1.0
			_hop = 0.0
			_hop_v = 0.0
			_sigh_t = -1.0
			_shake_t = -1.0
			_swish_t = -1.0
			_set_all(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
		return
	_still = false
	delta = minf(delta, 0.1)  # after a hitch, carry on rather than jump
	_t += delta
	_step_blink(delta)
	# reactions
	# the perk-up spring, in small steps so a slow frame can't upset it
	var left := delta
	while left > 0.0:
		var dt := minf(left, 1.0 / 120.0)
		_hop_v += (-170.0 * _hop - 13.0 * _hop_v) * dt
		_hop += _hop_v * dt
		left -= dt
	if _sigh_t >= 0.0:
		_sigh_t += delta
		if _sigh_t > 1.6:
			_sigh_t = -1.0
	if _shake_t >= 0.0:
		_shake_t += delta
		if _shake_t > 0.7:
			_shake_t = -1.0
	if _swish_t >= 0.0:
		_swish_t += delta
		if _swish_t > 2.0:
			_swish_t = -1.0
	_apply()


func _apply() -> void:
	var p := fposmod(_t / breath_sec, 1.0)
	# in for 40% of the breath, out for the rest, eased both ways
	var b := smoothstep(0.0, 0.4, p) if p < 0.4 else 1.0 - smoothstep(0.4, 1.0, p)
	var lift := breath_px * b + _hop
	if _sigh_t >= 0.0:
		# a deep breath in, then sinking a little lower than usual
		var s := _sigh_t
		lift += 2.5 * sin(clampf(s / 0.5, 0.0, 1.0) * PI) - 3.0 * smoothstep(0.35, 0.7, s) * (1.0 - smoothstep(0.9, 1.6, s))
	var head := head_px * sin(TAU * _t / head_sec)
	if _shake_t >= 0.0:
		head += 3.2 * sin(TAU * _shake_t / 0.17) * exp(-_shake_t / 0.22)
	var gust := 0.85 + 0.15 * sin(TAU * _t / 13.0)
	var swish := 0.0
	var swish_ph := 0.0
	if _swish_t >= 0.0:
		# eased in (no jump when it starts), dying away
		swish = _swish_amp * smoothstep(0.0, 0.15, _swish_t) * exp(-_swish_t / 0.6)
		swish_ph = TAU * _swish_t / 0.8
	_set_all(lift, head, TAU * _t / sway_sec, sway_px * gust, swish_ph, swish, _blink_frame())


func _set_all(lift: float, head: float, phase: float, sway: float, swish_ph: float, swish: float, blink: float) -> void:
	_mat.set_shader_parameter("lift_px", lift)
	_mat.set_shader_parameter("head_px", head)
	_mat.set_shader_parameter("sway_phase", phase)
	_mat.set_shader_parameter("sway_px", sway)
	_mat.set_shader_parameter("swish_phase", swish_ph)
	_mat.set_shader_parameter("swish_px", swish)
	_mat.set_shader_parameter("blink_frame", blink)


func _step_blink(delta: float) -> void:
	if not _has_blink:
		return
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t > 0.19:
			_blink_t = -1.0
			if _double_next:
				_double_next = false
				_blink_wait = 0.16
			else:
				_blink_wait = randf_range(blink_every.x, blink_every.y)
				_double_next = randf() < 0.18
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_t = 0.0


## 0 open, 1 half-shut, 2 shut: lids come down fast and lift a bit slower.
func _blink_frame() -> float:
	if _blink_t < 0.0:
		return 0.0
	if _blink_t < 0.045:
		return 1.0
	if _blink_t < 0.115:
		return 2.0
	if _blink_t < 0.19:
		return 1.0
	return 0.0


## A reaction to the board, standing in for an expression change.
func react(expr: String) -> void:
	if _mat == null or GameState.settings.get("reduce_motion", false):
		return
	match expr:
		"happy", "surprised":
			_hop_v = maxf(_hop_v, 0.0) + 85.0
			_swish(6.0)
			if expr == "surprised" and _has_blink:
				_blink_t = 0.0
		"sad":
			_sigh_t = 0.0
			_swish(2.5)
		"angry":
			_shake_t = 0.0
			_swish(3.5)
			if _flash_tw and _flash_tw.is_valid():
				_flash_tw.kill()
			_flash_tw = create_tween()
			_flash_tw.tween_property(self, "self_modulate", Color(1.0, 0.8, 0.8), 0.08)
			_flash_tw.tween_property(self, "self_modulate", Color.WHITE, 0.35)


func _swish(amp: float) -> void:
	# Still swinging from the last one? Let it be (restarting would jump).
	if _swish_t >= 0.0 and _swish_amp * exp(-_swish_t / 0.6) > 0.4:
		return
	_swish_t = 0.0
	_swish_amp = amp
