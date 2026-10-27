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
## Advancing: the Continue button, a click anywhere on the scene, or
## Space/Enter (round 15 — only the small button worked before). Choices
## still need an explicit pick.
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
## A character can set her own lift with "portraitLift" in characters.json:
## Hazel's art ends at her chest, so she sits higher, clear of the box.
const PORTRAIT_H := 548.0
const PORTRAIT_LIFT := 178.0
## On-screen height of a full-body sprite (the screen area is ~732px tall), and
## how far below the top of the screen her head sits.
const FULL_BODY_H := 1180.0
const FULL_BODY_TOP := 22.0


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
			t.anchor_left = 0.5
			t.anchor_right = 0.5
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

	var cg_tex: Texture2D = ArtAssets.cg(char_id, cg_key) if cg_key != "" else null
	if cg_tex:
		var cg_img := TextureRect.new()
		cg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		cg_img.texture = cg_tex
		cg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		cg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(cg_img)
		portrait_host.visible = false
	elif cg_key != "":
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.12, 0.04, 0.14, 0.45)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(dim)
		stage.add_child(UITheme.corner_tag("CG placeholder · cg/%s.png" % cg_key))

	if not bg_tex and cg_key == "":
		# Inside the top-right corner (it used to be anchored so it hung off
		# the screen's right edge and got clipped out of sight).
		stage.add_child(UITheme.corner_tag("Art placeholder"))

	# ---- dialogue box: a compact card docked to the bottom of the screen ----
	var dock := VBoxContainer.new()
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock.alignment = BoxContainer.ALIGNMENT_END
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)

	var box_margin := MarginContainer.new()
	box_margin.add_theme_constant_override("margin_left", 16)
	box_margin.add_theme_constant_override("margin_right", 16)
	box_margin.add_theme_constant_override("margin_bottom", 16)
	box_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(box_margin)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.dialogue_style(accent))
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box_margin.add_child(box)
	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 10)
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
	var text_lbl := UITheme.body("", 16, UITheme.INK_ON_DARK)
	text_lbl.custom_minimum_size = Vector2(0, 70)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	box_v.add_child(text_lbl)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.mouse_filter = Control.MOUSE_FILTER_PASS
	box_v.add_child(footer)

	# Boxed so the closures below can mutate them: which line is showing, and
	# whether a line (advanceable) or a choice (needs a pick) is on screen.
	var idx := {"i": 0, "can_advance": false}

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

	fns.show_choices = func():
		idx.can_advance = false
		for c in footer.get_children():
			c.queue_free()
		# Keep whatever line was already on screen (the question she just
		# asked) instead of blanking it out; only fall back to a generic line
		# when there were no lines at all.
		if lines.is_empty():
			speaker_lbl.text = String(ch.get("name", ""))
			var fallback: String = String(ch.get("tagline", "")).trim_prefix("\"").trim_suffix("\"")
			text_lbl.text = fallback if not fallback.is_empty() else "What do you say?"
			text_lbl.add_theme_color_override("font_color", UITheme.INK_ON_DARK_SOFT)
			set_portrait.call("neutral")
		name_tag.modulate.a = 1.0 if speaker_lbl.text != "" else 0.0
		var hint := UITheme.body("Choose your reply:", 11, UITheme.INK_ON_DARK_SOFT)
		footer.add_child(hint)
		var first_choice: Button = null
		var slot := String(choice_data.get("slot", ""))
		for option in choice_data.options:
			var btn := UITheme.make_card_button(String(option.label), accent)
			btn.pressed.connect(func():
				SFX.nav()
				StoryFlow.apply_choice(char_id, option, slot)
				var resp: Array = option.get("resp", [])
				if resp.is_empty():
					on_done.call()
				else:
					main.show_vn_scene(char_id, resp, null, on_done)
			)
			footer.add_child(btn)
			if first_choice == null:
				first_choice = btn
		fns.focus.call(first_choice, [["move", "Choose"], ["accept", "Reply"], ["pause", "Settings"]])

	fns.show_line = func():
		for c in footer.get_children():
			c.queue_free()
		var line: Dictionary = lines[idx.i]
		var is_narration: bool = String(line.get("k", "s")) == "n"
		speaker_lbl.text = "" if is_narration else String(ch.get("name", ""))
		name_tag.modulate.a = 0.0 if is_narration else 1.0
		text_lbl.text = String(line.get("t", ""))
		text_lbl.add_theme_color_override("font_color", UITheme.INK_ON_DARK_SOFT if is_narration else UITheme.INK_ON_DARK)
		var expr: String = String(line.get("e", "neutral"))
		set_portrait.call(expr)
		Voice.play_line(char_id, line)
		var cont := UITheme.make_primary_button("Continue  ▸")
		cont.pressed.connect(func(): fns.advance.call())
		footer.add_child(cont)
		idx.can_advance = true
		fns.focus.call(cont, [["accept", "Continue"], ["pause", "Settings"]])

	# Keys / a pad: the ring sits on Continue, or the first reply. With the
	# mouse, the scene itself keeps focus so Space/Enter still continue after
	# a click (a clicked Continue button is freed with its line).
	fns.focus = func(target: Control, hints: Array):
		main.nav_setup(target, Callable(), {}, hints)
		if not Nav.nav_mode:
			root.grab_focus.call_deferred()

	fns.advance = func():
		if not idx.can_advance:
			return
		idx.can_advance = false
		SFX.nav()
		idx.i += 1
		if idx.i < lines.size():
			fns.show_line.call()
		elif choice_data != null:
			fns.show_choices.call()
		else:
			on_done.call()

	# CG scenes: hide the dialogue box to see the whole picture. While it's
	# hidden, the next click / key brings it back instead of advancing.
	var hide_btn: Button = null
	if cg_key != "":
		var corner := MarginContainer.new()
		corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		corner.add_theme_constant_override("margin_top", 12)
		corner.add_theme_constant_override("margin_right", 12)
		root.add_child(corner)
		hide_btn = UITheme.make_glass_button("Hide text")
		hide_btn.focus_mode = Control.FOCUS_NONE
		corner.add_child(hide_btn)
		if not cg_tex:
			# keep clear of the placeholder tag in the same corner
			corner.add_theme_constant_override("margin_top", 44)
		fns.toggle_text = func():
			dock.visible = not dock.visible
			hide_btn.text = "Hide text" if dock.visible else "Show text"
		hide_btn.pressed.connect(func(): fns.toggle_text.call())

	# Click anywhere on the scene / Space / Enter = Continue. Not while the
	# Settings overlay is open (keyboard focus stays down here under it).
	root.gui_input.connect(func(ev: InputEvent):
		if main.has_method("is_settings_open") and main.is_settings_open():
			return
		if hide_btn != null:
			if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_H:
				root.accept_event()
				fns.toggle_text.call()
				return
			if not dock.visible and ((ev is InputEventMouseButton and ev.pressed) or ev.is_action_pressed("ui_accept")):
				root.accept_event()
				fns.toggle_text.call()
				return
		var go := false
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			go = true
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventKey and ev.echo):
			# Enter, Space, or A on a gamepad.
			go = true
		if go and idx.can_advance:
			root.accept_event()
			fns.advance.call()
	)
	root.grab_focus.call_deferred()

	if lines.is_empty():
		if choice_data != null:
			fns.show_choices.call()
		else:
			on_done.call()
	else:
		fns.show_line.call()
