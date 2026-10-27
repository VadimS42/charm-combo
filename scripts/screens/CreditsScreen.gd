## CreditsScreen.gd — credits plus the open-source license notices a shipped
## Godot game must include (round 15). The game's own credits come from
## data/credits.txt (plain text, edit freely); the engine and third-party
## notices are generated from the engine itself (Engine.get_license_text(),
## get_copyright_info(), get_license_info()), so they always match the Godot
## version the game was exported with.
class_name CreditsScreen
extends RefCounted

const CREDITS_PATH := "res://data/credits.txt"
const FONT_LICENSES_PATH := "res://data/font_licenses.txt"


static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT, UITheme.ACCENT_2))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	host.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var top_row := HBoxContainer.new()
	var back := UITheme.make_ghost_button("←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.show_menu()
	)
	top_row.add_child(back)
	outer.add_child(top_row)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.make_scroll_navigable(scroll)
	outer.add_child(scroll)
	var go_back := func():
		SFX.nav()
		main.show_menu()
	main.nav_setup(scroll, go_back, {}, [["move", "Scroll"], ["back", "Back"], ["pause", "Settings"]])
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(760, 0)
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	col.add_child(UITheme.heading("Credits", 24))
	var credits := "Charm Combo"
	if FileAccess.file_exists(CREDITS_PATH):
		credits = FileAccess.get_file_as_string(CREDITS_PATH).strip_edges()
	col.add_child(_para(credits, 14, UITheme.INK))

	col.add_child(UITheme.spacer(8))
	col.add_child(UITheme.heading("Made with Godot Engine", 18))
	col.add_child(_para("This game uses Godot Engine, available under the following license:", 12, UITheme.INK_SOFT))
	col.add_child(_para(Engine.get_license_text(), 11, UITheme.INK_SOFT))

	col.add_child(UITheme.spacer(8))
	col.add_child(UITheme.heading("Third-party components", 16))
	var parts: PackedStringArray = []
	for info in Engine.get_copyright_info():
		var line := String(info.get("name", ""))
		for part in info.get("parts", []):
			var cr: PackedStringArray = part.get("copyright", PackedStringArray())
			if not cr.is_empty():
				line += "\n    © " + "\n    © ".join(cr)
			line += "\n    License: " + String(part.get("license", ""))
		parts.append(line)
	col.add_child(_para("\n\n".join(parts), 11, UITheme.INK_SOFT))

	if FileAccess.file_exists(FONT_LICENSES_PATH):
		col.add_child(UITheme.spacer(8))
		col.add_child(UITheme.heading("Bundled fonts", 16))
		col.add_child(_para(FileAccess.get_file_as_string(FONT_LICENSES_PATH).strip_edges(), 11, UITheme.INK_SOFT))

	col.add_child(UITheme.spacer(8))
	col.add_child(UITheme.heading("License texts", 16))
	var licenses: Dictionary = Engine.get_license_info()
	var names := licenses.keys()
	names.sort()
	for lic in names:
		col.add_child(UITheme.body(String(lic), 12, UITheme.INK))
		col.add_child(_para(String(licenses[lic]), 10, UITheme.INK_SOFT))


static func _para(text: String, size: int, color: Color) -> Label:
	var l := UITheme.body(text, size, color)
	l.custom_minimum_size = Vector2(760, 0)
	return l
