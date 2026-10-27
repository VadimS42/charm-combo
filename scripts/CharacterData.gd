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


static func all() -> Array:
	if _cache.is_empty():
		_cache = _load()
	return _cache


static func _load() -> Array:
	if not FileAccess.file_exists(PATH):
		push_error("CharacterData: missing " + PATH)
		return []
	var f := FileAccess.open(PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("CharacterData: characters.json did not parse to an array")
		return []
	return parsed


static func by_id(char_id: String) -> Dictionary:
	for ch in all():
		if ch.get("id") == char_id:
			return ch
	return {}


## Maps a gem id string to the board-index used by MatchEngine (same 7-slot
## ordering as before — indices 0..5 are the "normal" pickable gem types a
## character can name as her fav/least, index 6 is the un-favoritable
## "cursed" piece). Renamed from the original generic heart/star/leaf/drop/
## note/gem set to a fantasy-flavored one for the succubus/mermaid/lamia/
## cat-girl cast — see the "puzzle pieces" note in README.md.
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
static func compute_weights(ch: Dictionary, chapter_idx: int) -> Array:
	var w: Array = MatchEngine.DEFAULT_WEIGHTS.duplicate()
	w[MatchEngine.BROKEN_IDX] = 2.0 + float(chapter_idx) * 1.2
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
