## ExtrasScreen.gd — the Gallery's Pictures, Music and Stats pages (round 49),
## and the full-screen picture viewer. Each page is a plain Control column,
## so the desktop Gallery (GalleryScreen, as tabs) and the phone Gallery tab
## (MobileShell) both use them.
class_name ExtrasScreen
extends RefCounted

## The soundtrack, in the order the Music page lists it: track key
## (audio/music/<key>.ogg), its name, and what unlocks it.
const TRACKS := [
	{"key": "menu", "name": "Sweet Serene", "by": "Fablefly Music", "unlock": ""},
	{"key": "succubus", "name": "Sexy Scene Instrumentals Vol. 4", "by": "Sascha Ende", "unlock": "met:succubus"},
	{"key": "mermaid", "name": "Underwater Theme II", "by": "Cleyton Kauffman", "unlock": "met:mermaid"},
	{"key": "slime", "name": "Binary Underwater Village", "by": "Alex McCulloch", "unlock": "met:slime"},
	{"key": "dryad", "name": "Enchanted Hollow", "by": "Eric Matyas", "unlock": "met:dryad"},
	{"key": "night", "name": "Sexy Scene Vol. 3", "by": "Sascha Ende", "unlock": "night"},
	{"key": "ending", "name": "morning_2d", "by": "", "unlock": "ending"},
]

const EXPRESSIONS := ["neutral", "happy", "shy", "teasing", "surprised", "sad", "angry"]
const THUMB := Vector2(168, 110)


# ---------------------------------------------------------------- Stats

static func stats_page(main: Node) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	var secs := GameState.stat("play_seconds")
	var rows := [
		["Play time", "%d h %02d min" % [secs / 3600, (secs / 60) % 60]],
		["Chapters cleared", str(GameState.stat("chapters_won"))],
		["Matches made", str(GameState.stat("matches"))],
		["Gems cleared", str(GameState.stat("gems"))],
		["Best combo", ("x%d" % GameState.stat("best_combo")) if GameState.stat("best_combo") > 0 else "-"],
		["Best chapter score", str(GameState.stat("best_score"))],
		["Special gems made", str(GameState.stat("specials"))],
		["Her powers used", str(GameState.stat("powers"))],
		["Amara's seals broken", str(GameState.stat("seals"))],
		["Comb pieces brought up", str(GameState.stat("combs"))],
		["Opal's things found", str(GameState.stat("items"))],
		["Hazel's blossoms grown", str(GameState.stat("blossoms"))],
	]
	for ch in CharacterData.all():
		var best := GameState.stat("free_" + String(ch.id))
		if best > 0:
			rows.append([UITheme.t("Best date with %s") % UITheme.first_name(String(ch.name)), str(best)])
	if GameState.stat("daily_best") > 0:
		rows.append(["Best daily challenge", str(GameState.stat("daily_best"))])
	for r in rows:
		var p := UITheme.panel(UITheme.SURFACE, 12, UITheme.LINE)
		var h := HBoxContainer.new()
		p.add_child(h)
		var name_l := UITheme.body(UITheme.t(String(r[0])), 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		var val := UITheme.heading(String(r[1]), 16)
		val.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(val)
		v.add_child(p)
	return v


# ---------------------------------------------------------------- Pictures

## Every picture the player has unlocked: [char_id, texture, label].
static func unlocked_pictures() -> Array:
	var out: Array = []
	for ch in CharacterData.all():
		var id := String(ch.id)
		var p := GameState.progress_for(id)
		var met: bool = not p.endings_unlocked.is_empty() or int(p.get("level_index", 0)) > 0 \
			or bool(p.get("_intro_done", false))
		if not met:
			continue
		var seen := {}
		var add := func(tex: Texture2D, label: String):
			if tex != null and not seen.has(tex):
				seen[tex] = true
				out.append([id, tex, label])
		var main_tex := ArtAssets.main_sprite(id)
		add.call(main_tex, UITheme.first_name(String(ch.name)))
		# Her puzzle background when she's painted into it (round 52).
		add.call(ArtAssets.background_for(String(ch.get("puzzleBg", ""))), UITheme.first_name(String(ch.name)))
		for e in EXPRESSIONS:
			var t := ArtAssets.character_portrait(id, e)
			if t != main_tex:
				add.call(t, UITheme.first_name(String(ch.name)))
		for entry in GameState.gallery:
			var parts := String(entry).split("|")
			if parts.size() < 2 or parts[0] != id:
				continue
			var ending := StoryFlow.ending_for_entry(id, parts[1], parts[2] if parts.size() > 2 else "")
			add.call(ArtAssets.cg(id, String(ending.get("cg", ""))), UITheme.t(String(ending.get("title", ""))))
			add.call(ArtAssets.cg(id, parts[1] + "_beat1"), UITheme.t(String(ending.get("title", ""))))
			add.call(ArtAssets.cg(id, parts[1] + "_beat2"), UITheme.t(String(ending.get("title", ""))))
			add.call(ArtAssets.ending_cg(id), UITheme.t(String(ending.get("title", ""))))
		if GameState.replays.has(id + "|night") and not Platform.sfw:
			for k in ["night_lead", "night", "night_act", "night_after"]:
				add.call(ArtAssets.cg_exact(id, k), UITheme.t("Her night scene"))
	return out


static func pictures_page(main: Node) -> Control:
	var pics := unlocked_pictures()
	if pics.is_empty():
		return UITheme.soft_label("Pictures appear here as you meet the girls and reach their endings.", 13)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for pic in pics:
		var tex: Texture2D = pic[1]
		var b := Button.new()
		b.custom_minimum_size = THUMB
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = String(pic[2])
		b.clip_contents = true
		b.add_theme_stylebox_override("focus", UITheme.focus_ring(8))
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.offset_left = 3
		t.offset_top = 3
		t.offset_right = -3
		t.offset_bottom = -3
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(t)
		b.pressed.connect(func():
			SFX.nav()
			view(main, tex))
		flow.add_child(b)
	return flow


## A picture over everything, as big as the screen allows, nothing else on
## screen. A click, tap, B, Esc or Backspace closes it.
static func view(main: Node, tex: Texture2D) -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.04, 0.96)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(t)
	var closer := Button.new()
	closer.flat = true
	closer.set_anchors_preset(Control.PRESET_FULL_RECT)
	closer.focus_mode = Control.FOCUS_ALL
	closer.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	closer.pressed.connect(func(): main.close_modal())
	shade.add_child(closer)
	main.open_modal(shade, closer)


# ---------------------------------------------------------------- Music

static func _track_unlocked(t: Dictionary) -> bool:
	var u := String(t.unlock)
	if u == "":
		return true
	if u.begins_with("met:"):
		var p := GameState.progress_for(u.substr(4))
		return not p.endings_unlocked.is_empty() or int(p.get("level_index", 0)) > 0 or bool(p.get("_intro_done", false))
	if u == "night":
		return not Platform.sfw and GameState.replays.any(func(r): return String(r).ends_with("|night"))
	if u == "ending":
		return not GameState.gallery.is_empty()
	return false


static func music_page(main: Node) -> Control:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	for t in TRACKS:
		if t.key == "night" and Platform.sfw:
			continue
		if not ResourceLoader.exists(Music.DIR + String(t.key) + ".ogg"):
			continue
		var open := _track_unlocked(t)
		var playing: bool = Music.current_path.get_file().get_basename() == String(t.key)
		var b := UITheme.make_primary_button("") if playing else UITheme.make_ghost_button("")
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = not open
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -16
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		h.add_child(UITheme.picture(ArtAssets.ui_icon("play"), 18))
		var name_l := UITheme.body(String(t.name) if open else UITheme.t("Not unlocked yet"), 14,
			Color.WHITE if playing else UITheme.INK)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_l.clip_text = true
		h.add_child(name_l)
		if open and String(t.by) != "":
			var by_l := UITheme.body(String(t.by), 11, Color(1, 1, 1, 0.85) if playing else UITheme.INK_SOFT)
			by_l.autowrap_mode = TextServer.AUTOWRAP_OFF
			by_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(by_l)
		h.alignment = BoxContainer.ALIGNMENT_BEGIN
		b.add_child(h)
		var key := String(t.key)
		b.pressed.connect(func():
			main.music_pick = key
			Music.play([key])
			main.call_deferred("refresh_extras"))
		v.add_child(b)
	return v
