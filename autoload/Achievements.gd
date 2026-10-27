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

## Hazel only for now (round 25): she's the girl with finished conversation
## art. The other three get their story achievements back once theirs is in.
## The puzzle ones count in anyone's chapters.
const LIST := [
	{"id": "HAZEL_MEET", "name": "Don't Even Think About It", "desc": "Meet Hazel instead of cutting her tree down."},
	{"id": "HAZEL_CH1", "name": "A Lovely Trench", "desc": "Clear Hazel's first chapter."},
	{"id": "HAZEL_CH2", "name": "Leaves Going Red", "desc": "Clear Hazel's second chapter."},
	{"id": "HAZEL_CH3", "name": "Out in the Storm", "desc": "Clear Hazel's third chapter."},
	{"id": "ENDING_HAZEL", "name": "Putting Down Roots", "desc": "Reach Hazel's ending."},
	{"id": "HAZEL_GIFT", "name": "Keeping Time", "desc": "Give Hazel the Brass Pocket Sundial."},
	{"id": "HAZEL_SWEET", "name": "Soft as Moss", "desc": "Finish Hazel's story picking every warm reply."},
	{"id": "HAZEL_TEASE", "name": "Splinters", "desc": "Finish Hazel's story teasing her in every reply."},
	{"id": "COMBO_3", "name": "Chain Reaction", "desc": "Set off a x3 combo."},
	{"id": "COMBO_5", "name": "Avalanche", "desc": "Set off a x5 combo."},
	{"id": "MAKE_STARBURST", "name": "Starstruck", "desc": "Make a Starburst."},
	{"id": "MEGA_BLAST", "name": "Mega Blast", "desc": "Swap two special gems together."},
	{"id": "CHARM_BURST", "name": "Irresistible", "desc": "Fill the Charm ring for a Charm Burst."},
	{"id": "MOVES_LEFT_5", "name": "With Moves to Spare", "desc": "Clear a chapter with 5 or more moves left."},
	{"id": "SHARD_SMASH", "name": "Shard Smasher", "desc": "Clear a cursed shard with the Hammer."},
	{"id": "FIRST_PURCHASE", "name": "Window Shopping", "desc": "Buy something in the Item Shop."},
]

const HAZEL := "dryad"
## Which girl each ending achievement belongs to (character id -> achievement).
const ENDING_BY_CHAR := {"dryad": "ENDING_HAZEL"}


func _ready() -> void:
	sync()


func info(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}


func is_unlocked(id: String) -> bool:
	return GameState.achievements.has(id)


## Only ids still in LIST (older saves can hold retired ones).
func unlocked_ids() -> Array:
	return GameState.achievements.filter(func(id): return not info(String(id)).is_empty())


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
	var p: Dictionary = GameState.characters_progress.get(HAZEL, {})
	if p.is_empty():
		return
	var ended: bool = not p.get("endings_unlocked", []).is_empty()
	var level := int(p.get("level_index", 0))
	var won: Array = p.get("won_levels", [])
	if bool(p.get("_intro_done", false)) or level > 0 or ended:
		unlock("HAZEL_MEET")
	for i in range(3):
		if won.has(i) or won.has(float(i)) or level > i or ended:
			unlock("HAZEL_CH%d" % (i + 1))
	if ended:
		# Her four replies (intro and chapters 1-3), all one way.
		var picks: Dictionary = p.get("choices", {})
		var stats: Array = picks.values().map(func(v): return String(v))
		if stats.size() >= 4 and stats.all(func(v): return v == "warmth"):
			unlock("HAZEL_SWEET")
		if stats.size() >= 4 and stats.all(func(v): return v == "spark"):
			unlock("HAZEL_TEASE")
	check_gallery()


func check_gallery() -> void:
	for e in GameState.gallery:
		var cid := String(e).split("|")[0]
		if ENDING_BY_CHAR.has(cid):
			unlock(ENDING_BY_CHAR[cid])


func check_gifts() -> void:
	var ch := CharacterData.by_id(HAZEL)
	var p: Dictionary = GameState.characters_progress.get(HAZEL, {})
	if not ch.is_empty() and p.get("gifts_given", []).has(String(ch.gift.id)):
		unlock("HAZEL_GIFT")


## The achievement's icon (art/achievements/<id lowercase>.png) or null.
static func icon(id: String) -> Texture2D:
	var path := "res://art/achievements/" + id.to_lower() + ".png"
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	return null
