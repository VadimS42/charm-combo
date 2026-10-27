@tool
extends EditorScript
## Writes docs/voice/voice_lines.csv from data/characters.json: every voiced
## line (spoken story lines and puzzle quips) with its ID, scene, text,
## emotion and delivery note, in play order. For refreshing the voice actor's
## list after editing dialogue when Python isn't installed: open this file in
## Godot's Script editor and choose File > Run (Ctrl+Shift+X). Excel opens the
## CSV directly. (tools/voice_script/ makes the full .xlsx and .docx.)
## Same order and scene names as tools/voice_script/make_voice_script.py.

const SRC := "res://data/characters.json"
const OUT := "res://docs/voice/voice_lines.csv"

var _rows: Array = []


func _run() -> void:
	var text := FileAccess.get_file_as_string(SRC)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("characters.json, line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
	_rows = [["Character", "Line ID", "File name", "Scene", "Line", "Emotion", "Delivery note"]]
	var counts := []
	for ch in json.data:
		var before := _rows.size()
		_collect(ch)
		counts.append("%s %d" % [String(ch.name), _rows.size() - before])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/voice"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		push_error("Can't write " + OUT)
		return
	f.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))  # so Excel reads it as UTF-8
	for r in _rows:
		var cells := PackedStringArray()
		for v in r:
			cells.append("\"" + String(v).replace("\"", "\"\"") + "\"")
		f.store_string(",".join(cells) + "\r\n")
	f.close()
	print("Wrote %s: %s" % [OUT, ", ".join(counts)])


func _collect(ch: Dictionary) -> void:
	var who := String(ch.name)
	var s: Dictionary = ch.story
	_block(who, s.intro, "Meeting her")
	_replies(who, s.get("introChoice"), "Meeting her")
	var levels: Array = s.levels
	for n in range(levels.size()):
		var last := " (last scene)" if n == levels.size() - 1 else ""
		_block(who, levels[n].win, "After chapter %d%s" % [n + 1, last])
		_replies(who, levels[n].get("choice"), "After chapter %d" % [n + 1])
	if typeof(s.get("night")) == TYPE_DICTIONARY:
		_block(who, s.night.get("lines", []), "Her night scene (full-screen CG)")
	for pair in [["warmth", "Warm ending"], ["spark", "Teasing ending"]]:
		var ep: Dictionary = s.endings[pair[0]].epilogue
		_block(who, ep.intro + ep.middle + ep.choice_lines, pair[1] + ": the morning after")
		var i := 1
		for o in ep.choice.options:
			_block(who, o.resp, "%s: final reply %d" % [pair[1], i])
			i += 1
	_block(who, ch.get("giftLine", []), "Gift scene (%s)" % String(ch.gift.name))
	for pair in [["favQuips", "Puzzle quip: you matched her favourite gem"],
			["leastQuips", "Puzzle quip: you matched a gem she dislikes"],
			["chatQuips", "Puzzle quip: chatter while you play"]]:
		for q in ch.get(pair[0], []):
			if typeof(q) == TYPE_DICTIONARY:
				_add(who, q, pair[1])


func _replies(who: String, choice, scene: String) -> void:
	if typeof(choice) != TYPE_DICTIONARY:
		return
	var i := 1
	for o in choice.options:
		_block(who, o.resp, "%s: reply %d" % [scene, i])
		i += 1


func _block(who: String, lines: Array, scene: String) -> void:
	for ln in lines:
		if String(ln.get("k", "")) == "s":
			_add(who, ln, scene)


func _add(who: String, ln: Dictionary, scene: String) -> void:
	var id := String(ln.get("id", "MISSING_ID"))
	_rows.append([who, id, id + ".wav", scene, String(ln.get("t", "")),
			String(ln.get("e", "neutral")), String(ln.get("d", ""))])
