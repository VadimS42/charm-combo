## Platform.gd (autoload singleton, registered in project.godot as "Platform")
##
## Which store build this is, and on Steam the bridge to the Steamworks API
## (round 16).
##
## Store builds are told apart by an export feature tag (export_presets.cfg):
##   "steam"  Windows (Steam) — talks to Steam through the GodotSteam plug-in
##   "itch"   the itch.io builds (Windows, Linux, macOS, Web) — never touch Steam
##   "epic"   Windows (Epic) (round 46) — safe for work, no Steam anywhere;
##            achievements go to Epic through addons/epic/epic_bridge.gd if
##            it's there (docs/EPIC_SETUP.md)
##   Android  (round 46) — the "android" platform: safe for work, touch
##   none of these: running from the editor
## The "sfw" feature (Epic and Android presets) or `-- --sfw` turns on the
## safe-for-work version of the story (sfw, StoryFlow.gd).
## Steam is optional everywhere: the GodotSteam plug-in (addons/godotsteam/,
## see docs/STEAM_SETUP.md) is looked up by name at runtime instead of being
## referenced in code, so the game compiles and runs the same without it —
## achievements then just live in the game (Achievements.gd), which is what
## itch.io players get anyway.
##
## What Steam gets when it's there: achievements (mirrored from
## Achievements.gd, including ones earned before Steam was connected), rich
## presence (what you're doing, in your friends list; the text lives in
## steam/rich_presence_english.vdf, uploaded in Steamworks), and a save when
## the Steam overlay opens. Cloud saves need no code (Steam Auto-Cloud, set up
## in Steamworks — see docs/STEAM_SETUP.md).
extends Node

## Your Steam App ID. Leave 0 until Steamworks gives you one (after the Steam
## Direct fee); until then Steam reads it from steam_appid.txt next to the exe
## when testing, or from the Steam client when launched from your library.
const STEAM_APP_ID := 0

## Exported Steam builds started outside Steam ask Steam to relaunch them
## (needs a real STEAM_APP_ID; never happens in the editor or debug builds).
const RESTART_THROUGH_STEAM := true

signal steam_ready

## Demo build (round 25): the "demo" export feature (preset "Windows (Demo)")
## or `-- --demo` on the command line. Only DEMO_CHAR's intro and first
## chapter play, then a "thanks for playing / wishlist" screen; nothing
## adult is reachable.
const DEMO_CHAR := "dryad"
## Where "Wishlist on Steam" goes. With a STEAM_APP_ID set, its store page;
## otherwise this (fill in your page's address once it exists).
const STORE_URL := ""
var demo := false
## Trailer capture (`-- --trailer`): chapters hide the HUD and the top bar,
## leaving the board, her and the combo pop-ups (record with --write-movie).
var trailer := false

## "steam", "itch", "epic", "android" or "none" (editor / untagged build).
var store := "none"
## The safe-for-work version (round 46): no night scenes or their pictures,
## no 18+ notice, and her safe-for-work lines, epilogues and pictures where
## characters.json / the art folders have them (see StoryFlow.sfw_lines()).
var sfw := false
## A phone or tablet (Android): touch, no window, no quitting by button.
var mobile := false
## Epic Online Services, through the optional bridge script (null without it).
var epic: Object = null
const EPIC_BRIDGE := "res://addons/epic/epic_bridge.gd"
## The GodotSteam singleton once Steam started successfully, else null.
var steam: Object = null
## Why Steam is or isn't running, for the log and the Credits screen.
var steam_status := "not used"


## The build flags are read here, not in _ready(): every autoload is created
## before any of them is ready, and GameState (which loads first) reads the
## story data while loading a save. Reading `sfw` late meant a returning
## player's safe-for-work build cached the full story (round 49 fix).
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	demo = OS.has_feature("demo") or args.has("--demo")
	trailer = args.has("--trailer")
	# `-- --mobile` tries the phone layout on PC (round 47).
	mobile = OS.has_feature("mobile") or args.has("--mobile")
	if OS.has_feature("steam"):
		store = "steam"
	elif OS.has_feature("itch"):
		store = "itch"
	elif OS.has_feature("epic"):
		store = "epic"
	elif OS.has_feature("android"):
		store = "android"
	sfw = OS.has_feature("sfw") or args.has("--sfw") or store == "epic" or store == "android"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if store == "epic":
		steam_status = "Epic build"
		_start_epic()
	elif store == "android":
		steam_status = "Android build"
	elif store == "itch":
		steam_status = "itch.io build"
	elif not Engine.has_singleton("Steam"):
		steam_status = "GodotSteam plug-in not installed" if store == "steam" else "not used"
	else:
		start_steam(Engine.get_singleton("Steam"))
	print("Charm Combo %s — %s build, Steam: %s" % [ProjectSettings.get_setting("application/config/version", ""), store, steam_status])


## Whether this build may point players at Steam (wishlist button, "unlocks on
## Steam too"). Never on Epic (its rules forbid links to other stores) or
## Android (round 46).
func links_to_steam() -> bool:
	return store == "steam" or store == "itch" or store == "none"


## Epic: the launcher starts the game with -AUTH_PASSWORD=, -epicapp= and so
## on (Godot leaves those alone); the bridge, if installed, signs in with them.
func _start_epic() -> void:
	if not ResourceLoader.exists(EPIC_BRIDGE):
		steam_status = "Epic build (no EOS bridge: achievements stay in the game)"
		return
	epic = load(EPIC_BRIDGE).new()
	add_child(epic)
	if epic.has_method("start"):
		epic.start(OS.get_cmdline_args())


## The language the Epic launcher asks for (-epiclocale=ru), or "".
static func store_locale() -> String:
	for a in OS.get_cmdline_args():
		if String(a).begins_with("-epiclocale="):
			return String(a).get_slice("=", 1).get_slice("-", 0).to_lower()
	return ""


## The store page to wishlist the game on ("" if there isn't one yet).
func wishlist_url() -> String:
	if not links_to_steam():
		return ""
	if STEAM_APP_ID > 0:
		return "https://store.steampowered.com/app/%d/" % STEAM_APP_ID
	return STORE_URL


## Initializes Steam through the given GodotSteam singleton (Steam's own, or
## a stand-in during tests). Works with both argument orders GodotSteam has
## used for steamInitEx() over its versions.
func start_steam(s: Object) -> bool:
	if s == null:
		return false
	if store == "steam" and STEAM_APP_ID > 0 and RESTART_THROUGH_STEAM and not OS.is_debug_build() \
			and s.has_method("restartAppIfNecessary"):
		if bool(s.restartAppIfNecessary(STEAM_APP_ID)):
			steam_status = "relaunching through Steam"
			get_tree().quit()
			return false

	var ok := false
	var detail := ""
	if s.has_method("steamInitEx"):
		var args := _arg_names(s, "steamInitEx")
		var result
		if not args.is_empty() and args[0] == "retrieve_stats":
			result = s.steamInitEx(true, STEAM_APP_ID, false)  # older GodotSteam
		else:
			result = s.steamInitEx(STEAM_APP_ID, false)
		if typeof(result) == TYPE_DICTIONARY:
			ok = int(result.get("status", 1)) == 0
			detail = String(result.get("verbal", ""))
	elif s.has_method("steamInit"):
		var result = s.steamInit()
		if typeof(result) == TYPE_DICTIONARY:
			ok = int(result.get("status", 0)) == 1  # GodotSteam 3.x: 1 = active
			detail = String(result.get("verbal", ""))
		elif typeof(result) == TYPE_BOOL:
			ok = not result  # newest steamInit(): true means it failed
	if not ok:
		steam_status = "Steam not available" + ((": " + detail) if detail != "" else "")
		print("Platform: ", steam_status)
		return false

	steam = s
	steam_status = "Steam connected"
	if s.has_signal("overlay_toggled"):
		s.connect("overlay_toggled", _on_overlay_toggled)
	print("Platform: Steam connected")
	# Achievements earned while Steam wasn't connected.
	for id in Achievements.unlocked_ids():
		set_achievement(id, false)
	_store_stats()
	steam_ready.emit()
	return true


static func _arg_names(o: Object, method: String) -> Array:
	for m in o.get_method_list():
		if String(m.name) == method:
			var names: Array = []
			for a in m.get("args", []):
				names.append(String(a.get("name", "")))
			return names
	return []


func _process(_delta: float) -> void:
	if steam != null:
		steam.run_callbacks()


func steam_active() -> bool:
	return steam != null


## Unlocks an achievement on Steam (API name = our achievement id). Skipped in
## Testing Mode so QA runs don't unlock them on your real account.
func set_achievement(id: String, store_now: bool = true) -> void:
	if bool(GameState.settings.get("test_mode", false)):
		return
	if epic != null and epic.has_method("unlock_achievement"):
		epic.unlock_achievement(id)
	if steam == null:
		return
	steam.setAchievement(id)
	if store_now:
		_store_stats()


## A Steam stat (round 49; API name = the key in GameState.stats, set up in
## Steamworks as an INT stat: see docs/STEAM_SETUP.md). Stored with the next
## achievement or on quit; skipped in Testing Mode.
func set_stat(key: String, value: int) -> void:
	if steam == null or bool(GameState.settings.get("test_mode", false)):
		return
	if steam.has_method("setStatInt"):
		steam.setStatInt(key, value)
	elif steam.has_method("setStat"):
		steam.setStat(key, value)


## A score on a Steam leaderboard (round 49: free play and the daily
## challenge). Leaderboards are created in Steamworks with these names; the
## upload keeps the player's best. No-op without Steam.
func post_score(board: String, score: int) -> void:
	if steam == null or bool(GameState.settings.get("test_mode", false)):
		return
	if not steam.has_signal("leaderboard_find_result"):
		return
	var cb := func(handle, found):
		if int(found) == 1 and steam.has_method("uploadLeaderboardScore"):
			steam.uploadLeaderboardScore(score, true, PackedInt32Array(), handle)
	if not steam.is_connected("leaderboard_find_result", cb):
		steam.connect("leaderboard_find_result", cb, CONNECT_ONE_SHOT)
	# Created on first use (descending, numeric), so the daily boards don't
	# each need setting up in Steamworks.
	if steam.has_method("findOrCreateLeaderboard"):
		steam.findOrCreateLeaderboard(board, 2, 1)
	elif steam.has_method("findLeaderboard"):
		steam.findLeaderboard(board)


func _store_stats() -> void:
	if steam != null:
		steam.storeStats()


## What you're doing, shown to Steam friends. status: "menu", "chapter",
## "story" or "ending" (tokens #Status_Menu … in the rich presence file).
func set_presence(status: String, girl: String = "", chapter: int = 0) -> void:
	if steam == null:
		return
	steam.setRichPresence("girl", girl)
	steam.setRichPresence("chapter", str(chapter))
	steam.setRichPresence("steam_display", "#Status_" + status.capitalize())


func is_steam_deck() -> bool:
	if OS.get_environment("SteamDeck") == "1":
		return true
	return steam != null and steam.has_method("isSteamRunningOnSteamDeck") and bool(steam.isSteamRunningOnSteamDeck())


func _on_overlay_toggled(active: bool, _user_initiated: bool = false, _app_id: int = 0) -> void:
	# The overlay is one way people quit or switch away; don't lose anything.
	if active:
		GameState.save_state()
