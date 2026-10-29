## CharacterData.gd
##
## Loads data/characters.json (a direct JSON export of the CHARACTERS array
## from the original HTML prototype — same ids, same dialogue, same level
## targets/moves, same endings) and exposes small lookup helpers.
##
## Kept as data on disk rather than hardcoded GDScript so writers can edit
## dialogue/levels without touching code, same spirit as the original file.
class_name CharacterData
extends RefCounted

const PATH := "res://data/characters.json"

static var _cache: Array = []
static var _error := ""
static var _source := ""


## Where the dialogue comes from. Normally the built-in data/characters.json.
## Test builds only (GameState.ALLOW_TESTING_MODE, so never a release build):
## a characters.json placed next to the game's .exe is used instead, so lines
## can be edited and tried straight away without re-exporting from Godot
## (docs/EDITING_DIALOGUE.md). Running from the Godot editor always uses the
## project's own file.
static func source_path() -> String:
	if GameState.ALLOW_TESTING_MODE and not OS.has_feature("editor") and not OS.has_feature("web"):
		var p := OS.get_executable_path().get_base_dir().path_join("characters.json")
		if FileAccess.file_exists(p):
			return p
	return PATH


## True when the edited copy next to the .exe is in use (the menu says so).
static func using_override() -> bool:
	all()
	return _source != "" and _source != PATH


static func all() -> Array:
	if _cache.is_empty():
		_cache = _load()
	return _cache


static func _load() -> Array:
	_source = source_path()
	var label := "data/characters.json" if _source == PATH else "characters.json (next to the game)"
	if not FileAccess.file_exists(_source):
		push_error("CharacterData: missing " + _source)
		return []
	var f := FileAccess.open(_source, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		_error = "%s, line %d: %s" % [label, json.get_error_line(), json.get_error_message()]
		push_error("CharacterData: " + _error)
		return []
	var parsed = json.data
	if typeof(parsed) != TYPE_ARRAY:
		_error = label + " should start with [ and end with ] (a list of the four characters)."
		push_error("CharacterData: " + _error)
		return []
	return parsed


## "" when data/characters.json loaded fine; otherwise where it went wrong
## (Main shows it on screen instead of starting the game).
static func load_error() -> String:
	all()
	return _error


static func by_id(char_id: String) -> Dictionary:
	for ch in all():
		if ch.get("id") == char_id:
			return ch
	return {}


## Maps a gem id string to the board-index used by MatchEngine (same 7-slot
## ordering as before — indices 0..5 are the "normal" pickable gem types a
## character can name as her fav/least, index 6 is the un-favoritable
## "cursed" piece). Renamed from the original generic heart/star/leaf/drop/
## note/gem set to a fantasy-flavored one for the succubus/mermaid/slime/
## dryad cast — see the "puzzle pieces" note in README.md.
static func gem_index_from_id(gem_id: String) -> int:
	match gem_id:
		"ember": return 0
		"moonstone": return 1
		"petal": return 2
		"pearl": return 3
		"rune": return 4
		"crystal": return 5
		"cursed": return 6
	return -1


static func gem_label(gem_id: String) -> String:
	match gem_id:
		"ember": return "Ember"
		"moonstone": return "Moonstone"
		"petal": return "Petal"
		"pearl": return "Pearl"
		"rune": return "Rune"
		"crystal": return "Crystal"
		"cursed": return "Cursed Shard"
	return gem_id.capitalize()


## Gem colors for the fantasy-themed piece set. Index matches
## gem_index_from_id() / MatchEngine board values. These are also the
## fallback flat-icon colors used when no real art exists yet at
## res://art/gems/<name>.png (see ArtAssets.gd).
static func gem_color(type_index: int) -> Color:
	match type_index:
		0: return Color("#FF7A4D")  # ember
		1: return Color("#C9B6FF")  # moonstone
		2: return Color("#FF8FB3")  # petal
		3: return Color("#4FD0E0")  # pearl
		4: return Color("#7C6BFF")  # rune
		5: return Color("#3FC9BE")  # crystal
		6: return Color("#5B5560")  # cursed shard
	return Color.WHITE


## Builds this chapter's gem weights: a baseline color spread, a "cursed
## shard" (broken-heart-equivalent) weight that climbs with chapter
## difficulty, and any active store boosts. Direct port of the original HTML
## prototype's computeWeights(ch, chapterIdx) — same formula, same store item
## effects, so the difficulty curve matches what was already tuned/playtested
## there. See PuzzleScreen.setup() for where this gets called and the boosts
## actually get consumed.
## Her gift, once given, makes her favourite gem turn up this much more often
## in all her chapters for good (round 34): a weaker, permanent Favor Charm
## (that one is x2.2 for one chapter, and the two stack).
const GIFT_FAV_WEIGHT := 1.5


static func has_gift(ch: Dictionary) -> bool:
	var gift = ch.get("gift")
	if typeof(gift) != TYPE_DICTIONARY:
		return false
	return (GameState.progress_for(String(ch.id)).get("gifts_given", []) as Array).has(String(gift.id))


static func compute_weights(ch: Dictionary, chapter_idx: int) -> Array:
	var w: Array = MatchEngine.DEFAULT_WEIGHTS.duplicate()
	w[MatchEngine.BROKEN_IDX] = 2.0 + float(chapter_idx) * 1.2
	if has_gift(ch):
		var gift_fav := gem_index_from_id(String(ch.fav))
		if gift_fav >= 0:
			w[gift_fav] *= GIFT_FAV_WEIGHT
	if int(GameState.items.get("favorCharm", 0)) > 0:
		var fav_i := gem_index_from_id(String(ch.fav))
		var least_i := gem_index_from_id(String(ch.least))
		if fav_i >= 0:
			w[fav_i] *= 2.2
		if least_i >= 0:
			w[least_i] *= 0.4
	if int(GameState.items.get("heartMender", 0)) > 0:
		w[MatchEngine.BROKEN_IDX] *= 0.35
	return w


static func gem_name(type_index: int) -> String:
	match type_index:
		0: return "ember"
		1: return "moonstone"
		2: return "petal"
		3: return "pearl"
		4: return "rune"
		5: return "crystal"
		6: return "cursed"
	return "?"
