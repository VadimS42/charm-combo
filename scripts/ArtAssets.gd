## ArtAssets.gd
##
## The one place that knows where real art WOULD live once it exists.
## Every lookup here is "does a file exist at this exact path — if so, use
## it, otherwise return null and let the caller fall back to its current
## placeholder (a colored shape / emoji / flat tint)." This means dropping a
## correctly-named file into res://art/... is the ENTIRE integration step —
## no code changes needed anywhere else in the game.
##
## See README.md's "Art asset checklist" section for the full list of every
## file this looks for, exact filenames, recommended sizes, and per-
## character expression sets.
class_name ArtAssets
extends RefCounted

const CHAR_DIR := "res://art/characters/"
const BG_DIR := "res://art/backgrounds/"
const GEM_DIR := "res://art/gems/"
const STORE_DIR := "res://art/store/"
const FRAME_DIR := "res://art/frames/"
const MENU_ILLUSTRATION := "res://art/menu_illustration.png"

## All 7 expressions a character's portrait art should cover, matching the
## `"e"` field used throughout characters.json dialogue lines.
const EXPRESSIONS := ["neutral", "happy", "shy", "surprised", "teasing", "sad", "angry"]


static func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	return null


## res://art/characters/<char_id>/<expression>.png — falls back to
## "neutral.png" for that character if the specific expression is missing
## (so a first art pass can ship one pose and still look correct everywhere),
## then to null (caller shows its emoji/placeholder).
static func character_portrait(char_id: String, expression: String) -> Texture2D:
	var tex := _try_load(CHAR_DIR + char_id + "/" + expression + ".png")
	if tex:
		return tex
	if expression != "neutral":
		return _try_load(CHAR_DIR + char_id + "/neutral.png")
	return null


static var _idle_cache := {}

## res://art/characters/<char_id>/idle/idle_000.png, idle_001.png, ... — a
## looping idle animation that stands in for her static portrait on the right
## of her puzzle chapter (see FrameAnimation.gd; round 14, Marina's swim
## loop). Optional idle.json beside the frames sets {"fps": N, "sequence":
## [frame indices for one full cycle]}; without it the frames play as a plain
## ping-pong (0..last..1) at 24 fps, which is seamless whether or not the clip
## itself loops. Returns {} when she has neither frames nor a main sprite.
## Cached per character, so the frames load once per session rather than once
## per chapter.
##
## No animation but a main sprite (main_sprite(), round 18)? That one image
## is returned as a single still frame with "still": true, so her chapters
## show her whole figure in the same spot, with the same hop/slump/wobble
## reactions.
static func idle_animation(char_id: String) -> Dictionary:
	if _idle_cache.has(char_id):
		return _idle_cache[char_id]
	var result := {}
	# Browsers can't use the frames' BC7 compression (and the Web export
	# leaves them out): in the browser build she shows her main sprite or her
	# still portraits instead.
	if not OS.has_feature("web"):
		var dir := CHAR_DIR + char_id + "/idle/"
		var frames: Array = []
		for i in range(1000):
			var tex := _try_load(dir + "idle_%03d.png" % i)
			if tex == null:
				break
			frames.append(tex)
		if not frames.is_empty():
			var fps := 24.0
			var seq := PackedInt32Array()
			var meta_path := dir + "idle.json"
			if FileAccess.file_exists(meta_path):
				var parsed = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
				if typeof(parsed) == TYPE_DICTIONARY:
					fps = float(parsed.get("fps", fps))
					for v in parsed.get("sequence", []):
						var idx := int(v)
						if idx >= 0 and idx < frames.size():
							seq.append(idx)
			if seq.size() < 2:
				for i in range(frames.size()):
					seq.append(i)
				for i in range(frames.size() - 2, 0, -1):
					seq.append(i)
			result = {"frames": frames, "sequence": seq, "fps": fps}
	if result.is_empty():
		var still := main_sprite(char_id)
		if still:
			result = {"frames": [still], "sequence": PackedInt32Array([0]), "fps": 1.0, "still": true}
	_idle_cache[char_id] = result
	return result


static var _live_cache := {}

## res://art/characters/<char_id>/live/ — her main sprite cut into a "live"
## rig (round 20, first Hazel), played by LiveSprite.gd in her puzzle
## chapters instead of the still main sprite or a frame animation:
##   base.png   her body, head and surroundings, free-hanging hair cut out
##   hair.png   that hair alone          mask.png  breathing/head/occlusion
##   blink.png  optional [half-shut | shut] eye patches
##   live.json  where the eye patches go, plus motion settings
## All four PNGs are the main sprite's size; the art tools that make them
## (tools/live_rig/) are described in docs/ART_LIST.md. Returns {} when
## base, hair or mask is missing. Cached per character.
static func live_rig(char_id: String) -> Dictionary:
	if _live_cache.has(char_id):
		return _live_cache[char_id]
	var dir := CHAR_DIR + char_id + "/live/"
	var result := {}
	var base := _try_load(dir + "base.png")
	var hair := _try_load(dir + "hair.png")
	var mask := _try_load(dir + "mask.png")
	if base and hair and mask:
		var cfg := {}
		if FileAccess.file_exists(dir + "live.json"):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir + "live.json"))
			if typeof(parsed) == TYPE_DICTIONARY:
				cfg = parsed
		result = {"base": base, "hair": hair, "mask": mask, "blink": _try_load(dir + "blink.png"), "config": cfg}
	_live_cache[char_id] = result
	return result


## res://art/characters/<char_id>/main.png — her main sprite: one full-figure
## picture (round 18, first Hazel sitting on her tree). It's what her puzzle
## chapters show on the right when she has no idle animation (see
## idle_animation()); conversations and her roster card keep using her seven
## expression pictures.
static func main_sprite(char_id: String) -> Texture2D:
	return _try_load(CHAR_DIR + char_id + "/main.png")


## res://art/characters/<char_id>/ending.png — a dedicated "final CG" pose
## for the Ending screen / Gallery. Falls back to her neutral portrait, then
## to null.
static func ending_cg(char_id: String) -> Texture2D:
	var tex := _try_load(CHAR_DIR + char_id + "/ending.png")
	if tex:
		return tex
	return character_portrait(char_id, "neutral")


## A character sprite drawn full-body (head to toe / tail) rather than
## waist-up: anything at least 1.5x as tall as it is wide. Screens frame the
## two differently (VNScreen, PuzzleScreen, RosterScreen).
static func is_full_body(tex: Texture2D) -> bool:
	return tex != null and float(tex.get_height()) >= 1.5 * float(maxi(1, tex.get_width()))


## Story CGs: res://art/characters/<char_id>/cg/<cg_key>.png, one image per
## moment of her ending (round 15). cg_key is set by StoryFlow:
##   "<ending>_beat1", "<ending>_beat2"   the two epilogue art beats
##   "<ending>_<finale>"                  each final CG (e.g. "warmth_window")
##   "<ending>"                           an ending with no epilogue choice
## Falls back to cg/<ending>.png (one image for that whole ending); returns
## null when there's no dedicated CG at all, and the screen shows its
## portrait-over-background stand-in instead (EndingCGScreen.art_frame()).
static func cg(char_id: String, cg_key: String) -> Texture2D:
	if cg_key == "":
		return null
	var dir := CHAR_DIR + char_id + "/cg/"
	var tex := _try_load(dir + cg_key + ".png")
	if tex:
		return tex
	var ending_key := cg_key.get_slice("_", 0)
	if ending_key != cg_key:
		return _try_load(dir + ending_key + ".png")
	return null


## Exactly art/characters/<id>/cg/<cg_key>.png, no fallback (a night scene's
## later pictures: missing = keep the one showing).
static func cg_exact(char_id: String, cg_key: String) -> Texture2D:
	if cg_key == "":
		return null
	return _try_load(CHAR_DIR + char_id + "/cg/" + cg_key + ".png")


## res://art/gifts/<gift_id>.png — the roster's gift button icon (gift ids are
## in characters.json, e.g. "pocketSundial"). Falls back to a 🎁 emoji.
static func gift_icon(gift_id: String) -> Texture2D:
	return _try_load("res://art/gifts/" + gift_id + ".png")


## res://art/ui/<name>.png — interface icons that currently fall back to emoji
## or plain text: "logo", "star", "heart", "settings", "hourglass", "play",
## "store", "gallery", "credits", "quit". See README's art checklist.
static func ui_icon(icon_name: String) -> Texture2D:
	return _try_load("res://art/ui/" + icon_name + ".png")


## res://art/backgrounds/<bg_key>.png — bg_key is each character's "bg"
## field in characters.json (e.g. "succubus_library"). Used full-bleed behind
## her puzzle chapter and (if present) her VN dialogue stage.
static func background_for(bg_key: String) -> Texture2D:
	if bg_key.is_empty():
		return null
	return _try_load(BG_DIR + bg_key + ".png")


## res://art/menu_illustration.png — the main menu's hero art.
static func menu_illustration() -> Texture2D:
	return _try_load(MENU_ILLUSTRATION)


## res://art/gems/<gem_name>.png — one of ember/moonstone/petal/pearl/rune/
## crystal/cursed (see CharacterData.gem_name()), plus the 3 specials:
## rocket_h/rocket_v/starburst.
static func gem_icon(name: String) -> Texture2D:
	return _try_load(GEM_DIR + name + ".png")


## res://art/store/<item_id>.png — Item Shop icons (moves/hammer/shuffle/
## colorBomb/favorCharm/heartMender). Falls back to the item's emoji.
static func store_icon(item_id: String) -> Texture2D:
	return _try_load(STORE_DIR + item_id + ".png")


## res://art/frames/<char_id>.png — a decorative border themed to each
## heroine, drawn behind the puzzle board itself (see PuzzleScreen.gd) so
## the board reads as sitting inside something that belongs to her chapter
## instead of a generic panel. Falls back to null (caller draws a plain
## placeholder frame so the board never looks unfinished).
static func puzzle_frame(char_id: String) -> Texture2D:
	return _try_load(FRAME_DIR + char_id + ".png")
