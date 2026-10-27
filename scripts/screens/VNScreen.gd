## VNScreen.gd — the visual-novel dialogue/choice screen, equivalent to
## #screen-scene in the HTML prototype. Handles three shapes of call:
##   1. A line sequence ending with no choice (lines=[...], choice_data=null)
##   2. A line sequence ending in a choice (lines=[...], choice_data={...})
##   3. A bare choice with no lead-in lines (lines=[], choice_data={...}) —
##      kept as a defensive fallback; StoryFlow no longer actually produces
##      this shape (see the intro-choice fix below), but a future data file
##      could still pass one.
##
## Portraits use real art the moment res://art/characters/<id>/<expr>.png
## exists (see ArtAssets.gd); until then, the same big reactive emoji this
## always used.
class_name VNScreen
extends RefCounted

const EXPR_ICON := {
	"neutral": "🙂", "happy": "😄", "shy": "😳", "surprised": "😲",
	"teasing": "😏", "sad": "😔", "angry": "😠",
}


static func build(main: Node, host: Control, char_id: String, lines: Array, choice_data, on_done: Callable) -> void:
	var ch: Dictionary = CharacterData.by_id(char_id) if char_id != "" else {}
	var accent: Color = Color(String(ch.c)) if ch.has("c") else UITheme.ACCENT

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	host.add_child(root)

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 220)
	stage.clip_contents = true
	# PanelContainer only lays out a single direct child sanely (extra
	# children all get stretched to the same rect) — so give it one plain
	# Control to hold the background, the centered portrait, and the corner
	# tag.
	var stage_inner := Control.new()
	stage_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(stage_inner)

	var bg_tex := ArtAssets.background_for(String(ch.get("bg", "")))
	if bg_tex:
		stage.add_theme_stylebox_override("panel", UITheme.panel_style(Color.WHITE, 18, accent.lightened(0.5)))
		var bg_img := TextureRect.new()
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		stage_inner.add_child(bg_img)
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(0, 0, 0, 0.12)
		stage_inner.add_child(scrim)
	else:
		stage.add_theme_stylebox_override("panel", UITheme.panel_style(accent.lightened(0.8), 18, accent.lightened(0.5)))

	var portrait_host := Control.new()
	portrait_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage_inner.add_child(portrait_host)

	var set_portrait: Callable = func(expr: String):
		for c in portrait_host.get_children():
			c.queue_free()
		var tex := ArtAssets.character_portrait(char_id, expr)
		if tex:
			var t := TextureRect.new()
			t.set_anchors_preset(Control.PRESET_FULL_RECT)
			t.texture = tex
			t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_host.add_child(t)
		else:
			var center := CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			var lbl := Label.new()
			lbl.add_theme_font_size_override("font_size", 72)
			lbl.text = EXPR_ICON.get(expr, "🙂")
			center.add_child(lbl)
			portrait_host.add_child(center)
	set_portrait.call("neutral")

	if not bg_tex:
		var tag := UITheme.placeholder_tag()
		tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		stage_inner.add_child(tag)

	root.add_child(stage)

	var box := UITheme.panel(UITheme.SURFACE, 18, UITheme.LINE)
	root.add_child(box)
	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 10)
	box.add_child(box_v)

	var speaker_lbl := UITheme.accent_label("", accent, 15)
	box_v.add_child(speaker_lbl)
	var text_lbl := UITheme.body("", 16)
	text_lbl.custom_minimum_size = Vector2(0, 70)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	box_v.add_child(text_lbl)

	var footer := VBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box_v.add_child(footer)

	var idx := {"i": 0}  # boxed so the closures below can mutate it

	# NOTE on a real GDScript footgun: these three functions call each other
	# (show_line's Continue button calls advance, which calls show_line or
	# show_choices). If they were plain `var show_line: Callable` locals
	# assigned in sequence, a closure created by an EARLIER assignment
	# (e.g. show_line's body referencing `advance`) captures whatever value
	# `advance` held at the moment that closure was CREATED — which is an
	# empty/null Callable, since `advance` isn't assigned until afterward.
	# That's exactly why the Continue button silently did nothing: it was
	# wired to a stale, empty Callable. Dictionaries are captured by
	# *reference* in GDScript closures, so stashing the functions as entries
	# in one shared dict and always calling through `fns.xxx.call()` (never
	# a bare local variable) means every closure sees the CURRENT value at
	# call time, regardless of definition order.
	var fns := {}

	fns.show_choices = func():
		for c in footer.get_children():
			c.queue_free()
		# Keep whatever line was already on screen (the question/lead-in she
		# just said) instead of blanking it out — the player should always
		# be able to see what they're actually replying to. Only fall back
		# to a generic line when there was truly nothing shown yet (a bare
		# choice with no lines at all).
		if lines.is_empty():
			speaker_lbl.text = String(ch.get("name", ""))
			var fallback: String = String(ch.get("tagline", "")).trim_prefix("\"").trim_suffix("\"")
			text_lbl.text = fallback if not fallback.is_empty() else "What do you say?"
			text_lbl.add_theme_color_override("font_color", UITheme.INK_SOFT)
			set_portrait.call("neutral")
		var hint := UITheme.soft_label("Choose your reply:", 10)
		footer.add_child(hint)
		for option in choice_data.options:
			var btn := UITheme.make_card_button(String(option.label), accent)
			btn.pressed.connect(func():
				SFX.nav()
				StoryFlow.apply_choice(char_id, option)
				var resp: Array = option.get("resp", [])
				if resp.is_empty():
					on_done.call()
				else:
					main.show_vn_scene(resp, null, on_done)
			)
			footer.add_child(btn)

	fns.show_line = func():
		for c in footer.get_children():
			c.queue_free()
		var line: Dictionary = lines[idx.i]
		var is_narration: bool = String(line.get("k", "s")) == "n"
		speaker_lbl.text = "" if is_narration else String(ch.get("name", ""))
		text_lbl.text = String(line.get("t", ""))
		text_lbl.add_theme_color_override("font_color", UITheme.INK_SOFT if is_narration else UITheme.INK)
		var expr: String = String(line.get("e", "neutral"))
		set_portrait.call(expr)
		var cont := UITheme.make_primary_button("Continue  ▸")
		cont.pressed.connect(func(): fns.advance.call())
		footer.add_child(cont)

	fns.advance = func():
		SFX.nav()
		idx.i += 1
		if idx.i < lines.size():
			fns.show_line.call()
		elif choice_data != null:
			fns.show_choices.call()
		else:
			on_done.call()

	if lines.is_empty():
		if choice_data != null:
			fns.show_choices.call()
		else:
			on_done.call()
	else:
		fns.show_line.call()
