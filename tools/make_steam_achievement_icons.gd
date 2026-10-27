## make_steam_achievement_icons.gd — editor helper (round 16).
##
## Steam wants two 256x256 icons per achievement: the "achieved" one and a
## grey "unachieved" one. The game only needs the achieved one
## (art/achievements/<id>.png, and it dims locked ones itself), so this makes
## the whole Steam upload set from those in one go:
##   steam/achievement_icons/<id>.png          achieved, 256x256
##   steam/achievement_icons/<id>_locked.png   greyed out, 256x256
##
## How to run it: open this file in Godot's Script editor, then File > Run
## (Ctrl+Shift+X). The Output panel lists what it wrote. Upload the pairs in
## Steamworks > Stats & Achievements > Achievements (docs/STEAM_SETUP.md).
@tool
extends EditorScript

const SRC_DIR := "res://art/achievements/"
const OUT_DIR := "res://steam/achievement_icons/"


func _run() -> void:
	var made := make_icons(SRC_DIR, OUT_DIR)
	if made == 0:
		print("No icons found in %s yet — see docs/ART_LIST.md for the list." % SRC_DIR)
	else:
		print("Wrote %d achieved + %d unachieved icons to %s" % [made, made, OUT_DIR])


## Returns how many icons it converted. Static so it can be tested outside the
## editor.
static func make_icons(src_dir: String, out_dir: String) -> int:
	var out_abs := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var made := 0
	for file in DirAccess.get_files_at(src_dir):
		if file.get_extension().to_lower() != "png":
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(src_dir.path_join(file)))
		if img == null or img.is_empty():
			push_warning("Couldn't read " + file)
			continue
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != 256 or img.get_height() != 256:
			img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		var id := file.get_basename().to_lower()
		img.save_png(out_abs.path_join(id + ".png"))
		_locked(img).save_png(out_abs.path_join(id + "_locked.png"))
		made += 1
	return made


## Greyscale, a little darker and flatter, so it reads as "not yet".
static func _locked(src: Image) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			l = lerpf(0.18, 0.62, l)
			img.set_pixel(x, y, Color(l, l, l, c.a))
	return img
