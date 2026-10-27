## Achievements.gd (autoload singleton, registered in project.godot as
## "Achievements") — round 16.
##
## The game's own achievement list. Unlocks are saved with the game
## (GameState.achievements) so every build has them — the in-game
## Achievements screen is how itch.io players see them — and are mirrored to
## Steam through Platform.gd when the Steam build is connected. Each id is also
## the achievement's API name in Steamworks (docs/STEAM_SETUP.md has the table
## to enter there), and its icon slot is art/achievements/<id in lowercase>.png.
##
## Story achievements are also re-checked from the save on every start
## (sync()), so progress made before this existed still counts.
extends Node

signal unlocked(id: String)

const LIST := [
	{"id": "FIRST_MEETING", "name": "Welcome to Duskhaven", "desc": "Get off on the wrong foot with someone."},
	{"id": "FIRST_CHAPTER", "name": "Opening Move", "desc": "Clear your first chapter."},
	{"id": "FIRST_GIFT", "name": "A Little Something", "desc": "Give someone a gift."},
	{"id": "ALL_GIFTS", "name": "Thoughtful", "desc": "Give all four gifts."},
	{"id": "ENDING_AMARA", "name": "Left the Candle Lit", "desc": "Reach an ending with Amara."},
	{"id": "ENDING_MARINA", "name": "High Tide", "desc": "Reach an ending with Marina."},
	{"id": "ENDING_OPAL", "name": "Out of the Jar", "desc": "Reach an ending with Opal."},
	{"id": "ENDING_HAZEL", "name": "Putting Down Roots", "desc": "Reach an ending with Hazel."},
	{"id": "ALL_FOUR", "name": "The Whole Circle", "desc": "Reach an ending with all four of them."},
	{"id": "BOTH_ROUTES", "name": "Two Sides of Her", "desc": "See a warm and a spark ending with the same woman."},
	{"id": "GALLERY_HALF", "name": "Collector", "desc": "Find half of the endings."},
	{"id": "GALLERY_FULL", "name": "Complete Gallery", "desc": "Find every ending."},
	{"id": "COMBO_3", "name": "Chain Reaction", "desc": "Set off a x3 combo."},
	{"id": "COMBO_5", "name": "Avalanche", "desc": "Set off a x5 combo."},
	{"id": "MAKE_STARBURST", "name": "Starstruck", "desc": "Make a Starburst."},
	{"id": "MEGA_BLAST", "name": "Mega Blast", "desc": "Swap two special gems together."},
	{"id": "CHARM_BURST", "name": "Irresistible", "desc": "Fill the Charm ring for a Charm Burst."},
	{"id": "MOVES_LEFT_5", "name": "With Moves to Spare", "desc": "Clear a chapter with 5 or more moves left."},
	{"id": "SHARD_SMASH", "name": "Shard Smasher", "desc": "Clear a cursed shard with the Hammer."},
	{"id": "FIRST_PURCHASE", "name": "Window Shopping", "desc": "Buy something in the Item Shop."},
]

## Which girl each ending achievement belongs to (character id -> achievement).
const ENDING_BY_CHAR := {
	"succubus": "ENDING_AMARA", "mermaid": "ENDING_MARINA",
	"slime": "ENDING_OPAL", "dryad": "ENDING_HAZEL",
}


func _ready() -> void:
	sync()


func info(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


func is_unlocked(id: String) -> bool:
	return GameState.achievements.has(id)


func unlocked_ids() -> Array:
	return GameState.achievements.duplicate()


func count_unlocked() -> int:
	var n := 0
	for a in LIST:
		if GameState.achievements.has(a.id):
			n += 1
	return n


## Unlocks `id` once: saves it, tells Steam (Platform.gd) and anyone listening
## (Main shows a toast when Steam isn't there to show its own). Unknown ids are
## ignored so a typo can't create a phantom achievement.
func unlock(id: String) -> void:
	if info(id).is_empty() or GameState.achievements.has(id):
		return
	GameState.achievements.append(id)
	GameState.save_state()
	Platform.set_achievement(id)
	unlocked.emit(id)


## Re-derives every achievement the save itself proves (reached endings,
## gifts, won chapters...) — on start, and after gallery/gift changes.
func sync() -> void:
	check_story()
	check_gifts()


func check_story() -> void:
	for id in GameState.characters_progress.keys():
		var p: Dictionary = GameState.characters_progress[id]
		if bool(p.get("_intro_done", false)) or int(p.get("level_index", 0)) > 0 \
				or not p.get("endings_unlocked", []).is_empty():
			unlock("FIRST_MEETING")
		if not p.get("won_levels", []).is_empty() or int(p.get("level_index", 0)) > 0 \
				or not p.get("endings_unlocked", []).is_empty():
			unlock("FIRST_CHAPTER")
	check_gallery()


func check_gallery() -> void:
	var routes := {}  # char id -> {ending key: true}
	for e in GameState.gallery:
		var parts := String(e).split("|")
		if parts.size() < 2:
			continue
		var cid := parts[0]
		if not routes.has(cid):
			routes[cid] = {}
		routes[cid][parts[1]] = true
	for cid in routes.keys():
		if ENDING_BY_CHAR.has(cid):
			unlock(ENDING_BY_CHAR[cid])
		if routes[cid].has("warmth") and routes[cid].has("spark"):
			unlock("BOTH_ROUTES")
	var all_four := true
	for cid in ENDING_BY_CHAR.keys():
		if not routes.has(cid):
			all_four = false
	if all_four:
		unlock("ALL_FOUR")
	var total := GalleryScreen.all_slots().size()
	var found := 0
	for s in GalleryScreen.all_slots():
		if GameState.gallery.has(s.entry):
			found += 1
	if total > 0 and found * 2 >= total:
		unlock("GALLERY_HALF")
	if total > 0 and found >= total:
		unlock("GALLERY_FULL")


func check_gifts() -> void:
	var given := 0
	for ch in CharacterData.all():
		var p: Dictionary = GameState.characters_progress.get(String(ch.id), {})
		if p.get("gifts_given", []).has(String(ch.gift.id)):
			given += 1
	if given >= 1:
		unlock("FIRST_GIFT")
	if given >= CharacterData.all().size():
		unlock("ALL_GIFTS")


## The achievement's icon (art/achievements/<id lowercase>.png) or null.
static func icon(id: String) -> Texture2D:
	var path := "res://art/achievements/" + id.to_lower() + ".png"
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	return null
