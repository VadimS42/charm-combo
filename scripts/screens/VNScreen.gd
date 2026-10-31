## VNScreen.gd — the visual-novel dialogue/choice screen, equivalent to
## #screen-scene in the HTML prototype. Handles three shapes of call:
##   1. A line sequence ending with no choice (lines=[...], choice_data=null)
##   2. A line sequence ending in a choice (lines=[...], choice_data={...})
##   3. A bare choice with no lead-in lines (lines=[], choice_data={...}) —
##      kept as a defensive fallback; StoryFlow no longer actually produces
##      this shape, but a future data file could still pass one.
##
## Portraits use real art the moment res://art/characters/<id>/<expr>.png
## exists (see ArtAssets.gd); until then, the same big reactive emoji this
## always used. Both framings work: a waist-up portrait (roughly 4:5, like
## Marina's) stands at a fixed width from the bottom of the screen, and a
## full-body sprite (anything at least 1.5x as tall as it is wide) is sized by
## height and hung from near the top of the screen, VN-style — head and
## shoulders in view, legs behind the dialogue box and off the bottom.
##
## Advancing: a click anywhere on the scene, Space/Enter, or A on a pad. A click
## while the text is still typing out finishes it first.
##
## Controls (round 25), in a row in the box and on keys / a pad:
##   Skip  hold Ctrl / RB, or toggle the button: races through lines already
##         read (GameState.seen_lines); stops at unread ones unless Settings
##         says "skip unread lines too", and always at a choice
##   Auto  A / Y or the button: lines carry on by themselves, after her voice
##         line ends (or a pause that grows with the line's length)
##   Log   L / LB, the button, or scrolling up: the last LOG_MAX lines
##   Hide  H / X on full-screen pictures (CG scenes)
## Choices show as a stack of pills over the left of the stage, with her line
## kept in the box under them; she stands right of centre to make room.
class_name VNScreen
extends RefCounted

const EXPR_ICON := {
	"neutral": "🙂", "happy": "😄", "shy": "😳", "surprised": "😲",
	"teasing": "😏", "sad": "😔", "angry": "😠",
}

## Height a waist-up portrait is scaled to (width follows its aspect ratio),
## and how far above the screen's bottom edge it ends: high enough that her
## chest sits just above the dialogue box (round 19; it used to stand on the
## bottom edge, hiding everything below her shoulders behind the box). The
## box is ~185 px tall; the last few pixels of the picture tuck behind it.
## A character can set her own lift with "portraitLift" in characters.json,
## and "portraitFade" (a fraction of the picture's height) fades the bottom of
## her picture out, so art that's cut off there never shows a hard edge
## through the see-through dialogue box (Hazel's ends at her chest).
const PORTRAIT_H := 548.0
const FADE_SHADER := preload("res://scripts/fade_bottom.gdshader")
const PORTRAIT_LIFT := 178.0
## On-screen height of a full-body sprite (the screen area is ~732px tall), and
## how far below the top of the screen her head sits.
const FULL_BODY_H := 1180.0
const FULL_BODY_TOP := 22.0
## Where she stands across the screen (0.5 = centre): a little right, leaving
## the left for reply choices.
const PORTRAIT_X := 0.6
## How many lines the Log keeps (across scenes, this session).
const LOG_MAX := 60
## Characters per second for each text speed setting (0 = all at once).
const TEXT_SPEEDS := {"slow": 22.0, "normal": 45.0, "fast": 100.0, "instant": 0.0}

## The Log: {"name", "text"} for the last LOG_MAX lines shown.
static var backlog: Array = []


## Identifies a line for "already read": its voice id, else its text.
static func line_key(char_id: String, line: Dictionary) -> String:
	var id := String(line.get("id", ""))
	if id != "":
		return id
	return "%s:%d" % [char_id, String(line.get("t", "")).hash()]


## A line can carry "cg" (round 29, night scenes: night_lead / night_act /
## night_after): when it shows, the full-screen picture crossfades to
## art/characters/<id>/cg/<cg>.png (0.4 s, instant under Reduce Motion) and
## stays until another line changes it. A missing file keeps the picture
## that's up. Lines' "cg" only applies in a CG scene (cg_key set).
##
## cg_key (round 22): play the scene over one of her full-screen CGs
## (ArtAssets.cg(): art/characters/<id>/cg/<cg_key>.png) instead of her
## portrait on a background — her night scene uses "night". With the art
## missing, the usual stage shows, dimmed and tagged as a placeholder. CG
## scenes get a "Hide text" button (and the H key) to look at the picture.
static func build(main: Node, host: Control, char_id: String, lines: Array, choice_data, on_done: Callable, cg_key: String = "") -> void:
	var ch: Dictionary = CharacterData.by_id(char_id) if char_id != "" else {}
	# "slot" entries are notes for writers (where your own lines go, see
	# docs/EDITING_DIALOGUE.md); they're never shown.
	lines = lines.filter(func(l): return typeof(l) == TYPE_DICTIONARY and String(l.get("k", "s")) != "slot")
	var accent: Color = Color(String(ch.c)) if ch.has("c") else UITheme.ACCENT

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Receives clicks that land anywhere on the scene (everything decorative
	# below passes the mouse through) plus Space/Enter, to advance.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.focus_mode = Control.FOCUS_ALL
	host.add_child(root)

	# ---- stage: background + her portrait, filling the WHOLE screen ----
	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage)

	var bg_tex := ArtAssets.background_for(String(ch.get("bg", "")))
	if bg_tex:
		var bg_img := TextureRect.new()
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(bg_img)
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(0, 0, 0, 0.12)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(scrim)
	else:
		# Same "no photo art yet" treatment as the other screens (flat
		# accent-tinted ground + soft blob backdrop).
		var flat := ColorRect.new()
		flat.color = accent.lightened(0.82)
		flat.set_anchors_preset(Control.PRESET_FULL_RECT)
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(flat)
		stage.add_child(UITheme.make_screen_backdrop(accent, accent.lightened(0.4)))

	var portrait_host := Control.new()
	portrait_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(portrait_host)

	var set_portrait: Callable = func(expr: String):
		for c in portrait_host.get_children():
			c.queue_free()
		var tex := ArtAssets.character_portrait(char_id, expr)
		if tex:
			var t := TextureRect.new()
			t.texture = tex
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var aspect: float = float(tex.get_height()) / float(max(1, tex.get_width()))
			t.anchor_left = PORTRAIT_X
			t.anchor_right = PORTRAIT_X
			if ArtAssets.is_full_body(tex):
				# Full-body sprite: sized by height, hung from near the top.
				var w: float = FULL_BODY_H / aspect
				t.anchor_top = 0.0
				t.anchor_bottom = 0.0
				t.offset_left = -w / 2.0
				t.offset_right = w / 2.0
				t.offset_top = FULL_BODY_TOP
				t.offset_bottom = FULL_BODY_TOP + FULL_BODY_H
			else:
				# Waist-up portrait: raised so the bottom of the picture (her
				# chest) ends just above the dialogue box.
				var w: float = PORTRAIT_H / aspect
				var lift: float = float(ch.get("portraitLift", PORTRAIT_LIFT))
				t.anchor_top = 1.0
				t.anchor_bottom = 1.0
				t.offset_left = -w / 2.0
				t.offset_right = w / 2.0
				t.offset_top = -lift - PORTRAIT_H
				t.offset_bottom = -lift
				var fade: float = float(ch.get("portraitFade", 0.0))
				if fade > 0.0:
					var mat := ShaderMaterial.new()
					mat.shader = FADE_SHADER
					mat.set_shader_parameter("fade", fade)
					t.material = mat
			portrait_host.add_child(t)
		else:
			var center := CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lbl := Label.new()
			lbl.add_theme_font_size_override("font_size", 120)
			lbl.text = EXPR_ICON.get(expr, "🙂")
			center.add_child(lbl)
			portrait_host.add_child(center)
	set_portrait.call("neutral")

	# The scene's first picture; its name falls back to the part before "_"
	# (night_lead -> night.png), then to the dimmed stage below.
	var cg_tex: Texture2D = ArtAssets.cg(char_id, cg_key) if cg_key != "" else null
	# The picture layer, and the placeholder pieces (dim, tag) that a later
	# real picture replaces.
	var cg_layer := Control.new()
	cg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cg_placeholder: Array = []
	if cg_tex:
		var cg_img := TextureRect.new()
		cg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		cg_img.texture = cg_tex
		cg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cg_layer.add_child(cg_img)
		portrait_host.visible = false
	elif cg_key != "":
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.12, 0.04, 0.14, 0.45)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(dim)
		var tag := UITheme.corner_tag("CG placeholder · cg/%s.png" % cg_key)
		stage.add_child(tag)
		cg_placeholder = [dim, tag]
	stage.add_child(cg_layer)

	# Switches the full-screen picture (a line's "cg"); exact file only, so a
	# missing one keeps what's showing.
	var set_cg := func(key: String):
		if cg_key == "" or key == "" or cg_layer.get_meta("cg", cg_key) == key:
			return
		var tex := ArtAssets.cg_exact(char_id, key)
		if tex == null:
			return
		cg_layer.set_meta("cg", key)
		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var old := cg_layer.get_children()
		cg_layer.add_child(img)
		var drop_old := func():
			for o in old:
				if is_instance_valid(o):
					o.queue_free()
			for p in cg_placeholder:
				if is_instance_valid(p):
					p.queue_free()
			portrait_host.visible = false
		if GameState.settings.get("reduce_motion", false):
			drop_old.call()
		else:
			img.modulate.a = 0.0
			var tw := img.create_tween()
			tw.tween_property(img, "modulate:a", 1.0, 0.4)
			tw.tween_callback(drop_old)

	if not bg_tex and cg_key == "":
		# Inside the top-right corner (it used to be anchored so it hung off
		# the screen's right edge and got clipped out of sight).
		stage.add_child(UITheme.corner_tag("Art placeholder"))

	# ---- dialogue box: docked to the bottom of the screen ----
	var dock := VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)

	# Reply choices: a stack of pills over the left of the stage.
	var choice_area := MarginContainer.new()
	choice_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_area.add_theme_constant_override("margin_left", 40)
	choice_area.add_theme_constant_override("margin_bottom", 18)
	choice_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(choice_area)
	var choice_col := VBoxContainer.new()
	choice_col.alignment = BoxContainer.ALIGNMENT_END
	choice_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	choice_col.custom_minimum_size = Vector2(560, 0)
	choice_col.add_theme_constant_override("separation", 12)
	choice_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_area.add_child(choice_col)

	var box_margin := MarginContainer.new()
	box_margin.add_theme_constant_override("margin_left", 16)
	box_margin.add_theme_constant_override("margin_right", 16)
	box_margin.add_theme_constant_override("margin_bottom", 16)
	box_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(box_margin)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.dialogue_style(accent))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.custom_minimum_size = Vector2(0, 196)
	box_margin.add_child(box)
	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 8)
	box_v.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(box_v)

	# Her name on a pill in her color (kept in place, just hidden, for
	# narration, so the box doesn't change height between lines).
	var name_tag := PanelContainer.new()
	var tag_style := UITheme.button_style(accent.darkened(0.08), 999)
	tag_style.content_margin_left = 14
	tag_style.content_margin_right = 14
	tag_style.content_margin_top = 3
	tag_style.content_margin_bottom = 4
	name_tag.add_theme_stylebox_override("panel", tag_style)
	name_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_v.add_child(name_tag)
	var speaker_lbl := UITheme.accent_label("", Color.WHITE, 15)
	speaker_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	speaker_lbl.add_theme_font_override("font", UITheme.tracked_font(1))
	name_tag.add_child(speaker_lbl)
	var text_lbl := UITheme.body("", 17, UITheme.INK_ON_DARK)
	text_lbl.custom_minimum_size = Vector2(0, 84)
	text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	text_lbl.add_theme_constant_override("shadow_offset_y", 1)
	box_v.add_child(text_lbl)

	# Bottom row: Log / Auto / Skip (/ Hide text on CGs) and the "next" arrow.
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 8)
	ctrl_row.mouse_filter = Control.MOUSE_FILTER_PASS
	box_v.add_child(ctrl_row)
	var mk := func(label: String, tip: String, icon: String = "") -> Button:
		var b := UITheme.make_glass_button(label)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = false
		b.tooltip_text = tip
		b.add_theme_font_size_override("font_size", 12)
		UITheme.add_icon(b, icon, 14)
		ctrl_row.add_child(b)
		return b
	var log_btn: Button = mk.call("Log", "Read back (L, or scroll up)", "log")
	var auto_btn: Button = mk.call("Auto", "Lines carry on by themselves (A)", "auto")
	var skip_btn: Button = mk.call("Skip", "Skip lines you've read (hold Ctrl)", "skip")
	var skip_all_btn: Button = mk.call("Skip unread", "Skip every line up to the next reply, read or not", "skip_all")
	var hide_btn: Button = null
	if cg_key != "":
		hide_btn = mk.call("Hide text", "See the whole picture (H)", "hide")
	var row_sp := Control.new()
	row_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl_row.add_child(row_sp)
	var next_lbl := UITheme.body("▼", 14, accent.lightened(0.35))
	next_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_lbl.modulate.a = 0.0
	ctrl_row.add_child(next_lbl)
	var next_tw := next_lbl.create_tween().set_loops()
	next_tw.tween_property(next_lbl, "position:y", 3.0, 0.45).as_relative().set_trans(Tween.TRANS_SINE)
	next_tw.tween_property(next_lbl, "position:y", -3.0, 0.45).as_relative().set_trans(Tween.TRANS_SINE)

	# Boxed so the closures below can mutate them.
	var st := {
		"i": 0, "can_advance": false, "typing": false, "skip": false,
		"auto": false, "ready_ms": -1, "choosing": false, "cur_seen": false,
		"skip_all": false, "type_tw": null,
	}

	# NOTE on a real GDScript footgun: these functions call each other, and a
	# lambda captures a plain local by VALUE at the moment it's created — a
	# closure made before `advance` was assigned would hold an empty Callable.
	# Keeping them in one shared dict and always calling through
	# `fns.xxx.call()` means every closure sees the current value.
	var fns := {}
	# The lambdas stored in `fns` capture `fns` itself — a reference cycle that
	# kept every finished scene's closures (and its lines) alive for the rest
	# of the session. Emptying it when the scene leaves the tree breaks it.
	root.tree_exited.connect(func(): fns.clear())

	var light := func(b: Button, on: bool):
		b.modulate = Color(1.25, 1.1, 1.25) if on else Color.WHITE
		b.add_theme_color_override("font_color", accent.lightened(0.45) if on else UITheme.INK_ON_DARK)

	fns.set_auto = func(on: bool):
		st.auto = on
		light.call(auto_btn, on)
	fns.set_skip = func(on: bool):
		st.skip = on
		light.call(skip_btn, on)
		if not on:
			st.skip_all = false
			light.call(skip_all_btn, false)
	# "Skip unread": skips everything up to the next reply.
	fns.set_skip_all = func(on: bool):
		fns.set_skip.call(on)
		st.skip_all = on
		light.call(skip_all_btn, on)

	# Whether skipping may pass the line on screen.
	fns.may_skip = func() -> bool:
		if st.choosing or st.i >= lines.size():
			return false
		# Whether it had been read BEFORE it came up this time (showing a
		# line marks it read).
		return st.skip_all or bool(GameState.settings.get("skip_unseen", false)) or st.cur_seen

	fns.finish_typing = func():
		st.typing = false
		# Stop the typing tween first: left running, it put the text back
		# to half-typed on the next frame, so a click seemed to do nothing.
		if st.type_tw is Tween and (st.type_tw as Tween).is_valid():
			(st.type_tw as Tween).kill()
		st.type_tw = null
		text_lbl.visible_ratio = 1.0
		next_lbl.modulate.a = 1.0
		st.ready_ms = Time.get_ticks_msec()

	fns.show_choices = func():
		st.can_advance = false
		st.choosing = true
		fns.set_skip.call(false)
		next_lbl.modulate.a = 0.0
		for c in choice_col.get_children():
			c.queue_free()
		# Keep whatever line was already on screen (the question she just
		# asked) instead of blanking it out; only fall back to a generic line
		# when there were no lines at all.
		if lines.is_empty():
			speaker_lbl.text = String(ch.get("name", ""))
			var fallback: String = UITheme.unquote(String(ch.get("tagline", "")))
			text_lbl.text = fallback if not fallback.is_empty() else "What do you say?"
			text_lbl.visible_ratio = 1.0
			text_lbl.add_theme_color_override("font_color", UITheme.INK_ON_DARK_SOFT)
			set_portrait.call("neutral")
		name_tag.modulate.a = 1.0 if speaker_lbl.text != "" else 0.0
		var first_choice: Button = null
		var slot := String(choice_data.get("slot", ""))
		var n := 0
		for option in choice_data.options:
			var btn := UITheme.make_choice_button(String(option.label), accent)
			btn.pressed.connect(func():
				SFX.nav()
				StoryFlow.apply_choice(char_id, option, slot)
				backlog.append({"name": "You", "text": String(option.label)})
				var resp: Array = option.get("resp", [])
				if resp.is_empty():
					on_done.call()
				else:
					main.show_vn_scene(char_id, resp, null, on_done)
			)
			choice_col.add_child(btn)
			# Slide in one after another.
			if not GameState.settings.get("reduce_motion", false):
				btn.modulate.a = 0.0
				var tw := btn.create_tween()
				tw.tween_interval(0.07 * n)
				tw.tween_property(btn, "modulate:a", 1.0, 0.18)
			n += 1
			if first_choice == null:
				first_choice = btn
		HowToPlay.tip(main, "replies")
		fns.focus.call(first_choice, [["move", "Choose"], ["accept", "Reply"], ["log", "Log"], ["pause", "Settings"]])

	fns.show_line = func():
		var line: Dictionary = lines[st.i]
		var is_narration: bool = String(line.get("k", "s")) == "n"
		var who := "" if is_narration else String(ch.get("name", ""))
		speaker_lbl.text = who
		name_tag.modulate.a = 0.0 if is_narration else 1.0
		var text := String(line.get("t", ""))
		text_lbl.text = text
		text_lbl.add_theme_color_override("font_color", UITheme.INK_ON_DARK_SOFT if is_narration else UITheme.INK_ON_DARK)
		set_portrait.call(String(line.get("e", "neutral")))
		set_cg.call(String(line.get("cg", "")))
		backlog.append({"name": who, "text": text})
		while backlog.size() > LOG_MAX:
			backlog.pop_front()
		var key := line_key(char_id, line)
		var was_seen: bool = GameState.seen_lines.has(key)
		st.cur_seen = was_seen
		GameState.seen_lines[key] = true
		# Racing through: no voice, no typing.
		var skipping: bool = (st.skip or Input.is_action_pressed("cc_skip")) and (was_seen or st.skip_all or bool(GameState.settings.get("skip_unseen", false)))
		if skipping:
			Voice.stop()
		else:
			Voice.play_line(char_id, line)
		next_lbl.modulate.a = 0.0
		st.can_advance = true
		var cps: float = float(TEXT_SPEEDS.get(String(GameState.settings.get("text_speed", "normal")), 45.0))
		if skipping or cps <= 0.0:
			fns.finish_typing.call()
		else:
			st.typing = true
			text_lbl.visible_ratio = 0.0
			var tw := text_lbl.create_tween()
			# Timed on the text as shown (the translation, if there is one).
			tw.tween_property(text_lbl, "visible_ratio", 1.0, maxf(0.05, UITheme.t(text).length() / cps))
			st.type_tw = tw
			tw.tween_callback(func():
				if st.typing and fns.has("finish_typing"):
					fns.finish_typing.call())
		fns.focus.call(root, [["accept", "Next"], ["skip", "Skip"], ["auto", "Auto"], ["log", "Log"], ["pause", "Settings"]])

	# Keys / a pad: the scene itself has focus (Enter / A = next line), or the
	# first reply. With the mouse, the scene keeps focus so Space/Enter still
	# work after a click.
	fns.focus = func(target: Control, hints: Array):
		# Back (Backspace / B) opens Settings, which has "Leave to Roster".
		main.nav_setup(target, func(): main.toggle_settings(), {}, hints)
		if not Nav.nav_mode or target == root:
			root.grab_focus.call_deferred()

	fns.advance = func():
		if not st.can_advance:
			return
		if st.typing:
			fns.finish_typing.call()
			return
		st.can_advance = false
		SFX.nav()
		st.i += 1
		if st.i < lines.size():
			fns.show_line.call()
		elif choice_data != null:
			fns.show_choices.call()
		else:
			GameState.save_state()
			on_done.call()

	fns.open_log = func():
		if main.modal_open():
			return
		fns.set_skip.call(false)
		show_log(main)

	# Skip and Auto run off a small timer.
	var ticker := Timer.new()
	ticker.wait_time = 0.06
	ticker.autostart = true
	root.add_child(ticker)
	ticker.timeout.connect(func():
		if not fns.has("advance") or main.modal_open() or (main.has_method("is_settings_open") and main.is_settings_open()):
			return
		if st.choosing or not st.can_advance:
			return
		var skipping: bool = st.skip or Input.is_action_pressed("cc_skip")
		if skipping:
			if fns.may_skip.call():
				if st.typing:
					fns.finish_typing.call()
				fns.advance.call()
			elif st.skip:
				fns.set_skip.call(false)  # reached a line you haven't read
			return
		if st.auto and not st.typing and not Voice.is_playing() and st.ready_ms >= 0:
			var line_len := text_lbl.text.length()
			var wait_ms := (900.0 + line_len * 35.0) * lerpf(0.5, 1.6, float(GameState.settings.get("auto_delay", 0.5)))
			# After a voice line (already waited out above), just a short beat.
			if Voice.enabled() and Voice.clip_path(char_id, String(lines[st.i].get("id", ""))) != "":
				wait_ms = 500.0
			if Time.get_ticks_msec() - st.ready_ms >= wait_ms:
				fns.advance.call()
	)

	log_btn.pressed.connect(func(): fns.open_log.call())
	auto_btn.pressed.connect(func(): fns.set_auto.call(not st.auto))
	skip_all_btn.pressed.connect(func(): fns.set_skip_all.call(not st.skip_all))
	skip_btn.pressed.connect(func():
		fns.set_skip.call(not st.skip)
		# Nothing read to skip to: it simply stays off.
		if st.skip and not fns.may_skip.call():
			fns.set_skip.call(false)
	)

	# CG scenes: hide the dialogue box to see the whole picture. While it's
	# hidden, the next click / key brings it back instead of advancing.
	if hide_btn != null:
		fns.toggle_text = func():
			dock.visible = not dock.visible
		hide_btn.pressed.connect(func(): fns.toggle_text.call())

	# Click anywhere on the scene / Space / Enter = next. Not while Settings or
	# a popup is open (keyboard focus stays down here under them).
	root.gui_input.connect(func(ev: InputEvent):
		if main.modal_open() or (main.has_method("is_settings_open") and main.is_settings_open()):
			return
		if ev is InputEventKey and ev.echo:
			return
		if hide_btn != null:
			if ev.is_action_pressed("cc_hide"):
				root.accept_event()
				fns.toggle_text.call()
				return
			if not dock.visible and ((ev is InputEventMouseButton and ev.pressed) or ev.is_action_pressed("ui_accept")):
				root.accept_event()
				fns.toggle_text.call()
				return
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			root.accept_event()
			fns.open_log.call()
			return
		if ev.is_action_pressed("cc_log"):
			root.accept_event()
			fns.open_log.call()
			return
		if ev.is_action_pressed("cc_auto"):
			root.accept_event()
			fns.set_auto.call(not st.auto)
			return
		var go := false
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			go = true
		elif ev.is_action_pressed("ui_accept"):
			# Enter, Space, or A on a gamepad.
			go = true
		if go and st.can_advance:
			root.accept_event()
			# A click stops Auto / Skip, like in most VNs.
			fns.set_skip.call(false)
			fns.advance.call()
	)
	root.grab_focus.call_deferred()

	HowToPlay.tip(main, "dialogue")
	if lines.is_empty():
		if choice_data != null:
			fns.show_choices.call()
		else:
			on_done.call()
	else:
		fns.show_line.call()


## The Log: the last lines shown, newest at the bottom, in Main's modal slot
## (Esc / B / the button / a click outside close it).
static func show_log(main: Node) -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.03, 0.1, 0.7)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			main.close_modal()
	)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.dialogue_style(UITheme.ACCENT))
	card.custom_minimum_size = Vector2(820, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var title := UITheme.heading("Log", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	v.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.make_scroll_navigable(scroll)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	if backlog.is_empty():
		list.add_child(UITheme.body("Nothing yet.", 14, UITheme.INK_ON_DARK_SOFT))
	for e in backlog:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		if String(e.name) != "":
			row.add_child(UITheme.accent_label(String(e.name), UITheme.ACCENT.lightened(0.3), 12))
		var t := UITheme.body(String(e.text), 15, UITheme.INK_ON_DARK if String(e.name) != "" else UITheme.INK_ON_DARK_SOFT)
		t.custom_minimum_size = Vector2(760, 0)
		row.add_child(t)
		list.add_child(row)
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(close_row)
	var close := UITheme.make_primary_button("Close")
	close.pressed.connect(func():
		SFX.nav()
		main.close_modal()
	)
	close_row.add_child(close)
	main.open_modal(shade, close)
	# Open at the newest line.
	(func(): scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)).call_deferred()
