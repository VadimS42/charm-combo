## EndingArtBeatScreen.gd — one "big CG reveal" beat inside a character's
## post-story epilogue (see StoryFlow._play_epilogue()): a big picture, an
## optional one-line caption underneath, and a "Continue" button. No title or
## name — these are transitional story moments, not the resolution.
##
## Each beat has its own image slot (round 15): cg_key is "<ending>_beat1" or
## "<ending>_beat2", looked up as art/characters/<id>/cg/<cg_key>.png (see
## ArtAssets.cg()); until that exists it shows the same stand-in as the ending
## screen (EndingCGScreen.art_frame()).
class_name EndingArtBeatScreen
extends RefCounted

static func build(main: Node, host: Control, char_id: String, caption: String, on_continue: Callable, cg_key: String = "") -> void:
	var ch := CharacterData.by_id(char_id)
	var accent: Color = Color(String(ch.get("c", "#FF6F91")))

	host.add_child(UITheme.make_screen_backdrop(accent, accent.lightened(0.3)))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	host.add_child(v)

	v.add_child(EndingCGScreen.art_frame(char_id, cg_key, Vector2(900, 506),
		"Epilogue art · placeholder", "💫"))

	if not caption.is_empty():
		var caption_lbl := UITheme.body(caption, 13, UITheme.INK_SOFT)
		caption_lbl.custom_minimum_size = Vector2(700, 0)
		caption_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(caption_lbl)

	var cont_btn := UITheme.make_primary_button("Continue")
	cont_btn.pressed.connect(func():
		SFX.nav()
		on_continue.call()
	)
	var cont_center := CenterContainer.new()
	cont_center.add_child(cont_btn)
	v.add_child(cont_center)
	main.nav_setup(cont_btn)
