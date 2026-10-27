## EndingCGScreen.gd — an ending's final CG: the picture, her ending's title
## and name, its text, and Continue. Shown once when her story finishes (the
## last beat of her epilogue), and reopenable from the Gallery / her card.
##
## The picture is her dedicated CG for this exact ending/finale when it exists
## (ArtAssets.cg(): art/characters/<id>/cg/<cg_key>.png, cg_key set by
## StoryFlow), filling the frame; otherwise the stand-in — her location
## background with her ending portrait (or an emoji) in front of it, tagged as
## a placeholder. The title sits BELOW the picture so it's never dark text
## laid over artwork.
class_name EndingCGScreen
extends RefCounted

static func build(main: Node, host: Control, char_id: String, ending: Dictionary, on_continue: Callable) -> void:
	var ch := CharacterData.by_id(char_id)
	var accent: Color = Color(String(ch.get("c", "#FF6F91")))

	host.add_child(UITheme.make_screen_backdrop(accent, accent.lightened(0.3)))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	host.add_child(v)

	v.add_child(art_frame(char_id, String(ending.get("cg", "")), Vector2(760, 400),
		"Ending CG · placeholder art", "💞"))

	var title_lbl := UITheme.heading(String(ending.get("title", "")), 26)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A word-wrapping Label in a centered column only gets its longest word's
	# width unless it's given a real one (titles used to break per word).
	title_lbl.custom_minimum_size = Vector2(720, 0)
	title_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(title_lbl)

	var name_lbl := UITheme.accent_label(String(ch.get("name", "")).to_upper(), accent.darkened(0.15), 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", UITheme.tracked_font(2))
	v.add_child(name_lbl)

	var text_lbl := UITheme.body(String(ending.get("text", "")), 13, UITheme.INK_SOFT)
	text_lbl.custom_minimum_size = Vector2(680, 0)
	text_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(text_lbl)

	var cont_btn := UITheme.make_primary_button("Continue")
	cont_btn.pressed.connect(func():
		SFX.nav()
		on_continue.call()
	)
	var cont_center := CenterContainer.new()
	cont_center.add_child(cont_btn)
	v.add_child(cont_center)
	main.nav_setup(cont_btn)


## The framed picture shared by this screen, EndingArtBeatScreen and the
## Gallery's thumbnails: her dedicated CG for `cg_key` filling the frame when
## it exists, else the stand-in (location background + ending portrait or
## `emoji`, tagged with `tag_text` unless that's ""). Square corners so a
## full-bleed CG sits exactly inside the border drawn over it.
static func art_frame(char_id: String, cg_key: String, frame_size: Vector2, tag_text: String, emoji: String) -> Control:
	var ch := CharacterData.by_id(char_id)
	var accent: Color = Color(String(ch.get("c", "#FF6F91")))

	var frame := Control.new()
	frame.custom_minimum_size = frame_size
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var cg_tex := ArtAssets.cg(char_id, cg_key)
	if cg_tex:
		var pic := TextureRect.new()
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.texture = cg_tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
	else:
		var base := ColorRect.new()
		base.set_anchors_preset(Control.PRESET_FULL_RECT)
		base.color = accent.lightened(0.78)
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(base)
		var bg_tex := ArtAssets.background_for(String(ch.get("bg", "")))
		if bg_tex:
			var bg_img := TextureRect.new()
			bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_img.texture = bg_tex
			bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(bg_img)
			var scrim := ColorRect.new()
			scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
			scrim.color = Color(0, 0, 0, 0.2)
			scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
			frame.add_child(scrim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait_tex := ArtAssets.ending_cg(char_id)
		if portrait_tex:
			var p := TextureRect.new()
			p.texture = portrait_tex
			p.custom_minimum_size = Vector2(0, frame_size.y - 30.0)
			p.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(p)
		else:
			var lbl := Label.new()
			lbl.text = emoji
			lbl.add_theme_font_size_override("font_size", mini(96, int(frame_size.y * 0.4)))
			center.add_child(lbl)
		frame.add_child(center)
		if tag_text != "":
			frame.add_child(UITheme.corner_tag(tag_text))

	var border := Panel.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.draw_center = false
	bs.border_color = accent.darkened(0.1)
	bs.set_border_width_all(3)
	border.add_theme_stylebox_override("panel", bs)
	frame.add_child(border)
	return frame
