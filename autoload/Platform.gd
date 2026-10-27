## Platform.gd (autoload singleton, registered in project.godot as "Platform")
##
## Which store build this is, and on Steam the bridge to the Steamworks API
## (round 16).
##
## Store builds are told apart by an export feature tag (export_presets.cfg):
##   "steam"  Windows (Steam) — talks to Steam through the GodotSteam plug-in
##   "itch"   the itch.io builds (Windows, Linux, macOS, Web) — never touch Steam
##   neither  running from the editor
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

## "steam", "itch" or "none" (editor / untagged build).
var store := "none"
## The GodotSteam singleton once Steam started successfully, else null.
var steam: Object = null
## Why Steam is or isn't running, for the log and the Credits screen.
var steam_status := "not used"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("steam"):
		store = "steam"
	elif OS.has_feature("itch"):
		store = "itch"
	if store == "itch":
		steam_status = "itch.io build"
	elif not Engine.has_singleton("Steam"):
		steam_status = "GodotSteam plug-in not installed" if store == "steam" else "not used"
	else:
		start_steam(Engine.get_singleton("Steam"))
	print("Charm Combo %s — %s build, Steam: %s" % [ProjectSettings.get_setting("application/config/version", ""), store, steam_status])


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
	if steam == null or bool(GameState.settings.get("test_mode", false)):
		return
	steam.setAchievement(id)
	if store_now:
		_store_stats()


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
	return steam != null and steam.has_method("isSteamRunningOnSteamDeck") and bool(steam.isSteamRunningOnSteamDeck())


func _on_overlay_toggled(active: bool, _user_initiated: bool = false, _app_id: int = 0) -> void:
	# The overlay is one way people quit or switch away; don't lose anything.
	if active:
		GameState.save_state()
