## EndingCGScreen.gd — the placeholder "ending CG" reveal screen, equivalent
## to #screen-cg in the HTML prototype. Shown once when a character's story
## finishes, and reopenable later from the Gallery.
class_name EndingCGScreen
extends RefCounted

static func build(main: Node, host: Control, char_id: String, ending: Dictionary, on_continue: Callable) -> void:
	var ch := CharacterData.by_id(char_id)
	var accent: Color = Color(String(ch.get("c", "#FF6F91")))

	host.add_child(UITheme.make_screen_backdrop(accent, accent.lightened(0.3)))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	host.add_child(v)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(520, 340)
	frame.clip_contents = true
	var ending_tex := ArtAssets.ending_cg(char_id)
	var bg_tex := ArtAssets.background_for(String(ch.get("bg", "")))

	if bg_tex or ending_tex:
		frame.add_theme_stylebox_override("panel", UITheme.panel_style(Color.WHITE, 22, accent.lightened(0.5)))
	else:
		frame.add_theme_stylebox_override("panel", UITheme.panel_style(accent.lightened(0.78), 22, accent.lightened(0.5)))

	var frame_inner := Control.new()
	frame_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(frame_inner)

	if bg_tex:
		var bg_img := TextureRect.new()
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame_inner.add_child(bg_img)
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(0, 0, 0, 0.2)
		frame_inner.add_child(scrim)

	var frame_center := CenterContainer.new()
	frame_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame_v := VBoxContainer.new()
	frame_v.alignment = BoxContainer.ALIGNMENT_CENTER
	frame_v.add_theme_constant_override("separation", 6)

	if not ending_tex:
		var tag := UITheme.placeholder_tag("Ending CG · placeholder art")
		frame_v.add_child(tag)

	if ending_tex:
		var portrait_tex := TextureRect.new()
		portrait_tex.texture = ending_tex
		portrait_tex.custom_minimum_size = Vector2(0, 220)
		portrait_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame_v.add_child(portrait_tex)
	else:
		var portrait := Label.new()
		portrait.text = "💞"
		portrait.add_theme_font_size_override("font_size", 96)
		portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame_v.add_child(portrait)

	var title_lbl := UITheme.heading(String(ending.title), 24)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame_v.add_child(title_lbl)

	var name_lbl := UITheme.accent_label(String(ch.get("name", "")).to_upper(), accent, 12)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame_v.add_child(name_lbl)

	frame_center.add_child(frame_v)
	frame_inner.add_child(frame_center)
	v.add_child(frame)

	var text_lbl := UITheme.body(String(ending.text), 13, UITheme.INK_SOFT)
	text_lbl.custom_minimum_size = Vector2(520, 0)
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
