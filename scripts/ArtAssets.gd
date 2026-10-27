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


## res://art/characters/<char_id>/ending.png — a dedicated "final CG" pose
## for the Ending screen / Gallery. Falls back to her neutral portrait, then
## to null.
static func ending_cg(char_id: String) -> Texture2D:
	var tex := _try_load(CHAR_DIR + char_id + "/ending.png")
	if tex:
		return tex
	return character_portrait(char_id, "neutral")


## res://art/backgrounds/<bg_key>.png — bg_key is each character's "bg"
## field in characters.json (e.g. "succubus_stage"). Used full-bleed behind
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
