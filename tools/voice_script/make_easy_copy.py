"""Charm Combo: every voiced line as plain text, one block per line, easy to
copy into a message or a casting call. Reads docs/voice/voice_lines.json (made
by make_voice_script.py). Writes docs/voice/lines_<name>.txt per character
and docs/voice/All_lines.txt.
Usage: python3 tools/voice_script/make_easy_copy.py"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "docs", "voice")
data = json.load(open(os.path.join(OUT, "voice_lines.json"), encoding="utf-8"))
everything = []
for c in data:
    first = c["name"].split()[0]
    out = [c["name"].upper() + " (" + c["role"] + ")", "", "Voice: " + c["voice"]]
    if c.get("pronunciation"):
        out.append("Say it: " + " · ".join("%s = %s" % (a, b) for a, b in c["pronunciation"]))
    out += ["", "%d lines. Emotion = the portrait she shows; after it, how to deliver the line." % len(c["lines"]), ""]
    scene = None
    for n, ln in enumerate(c["lines"], 1):
        if ln["scene"] != scene:
            scene = ln["scene"]
            out += ["", "== " + scene.upper() + " ==", ""]
        out.append("%d. %s" % (n, ln["line"]))
        note = ln.get("note", "")
        out.append("   Emotion: %s%s" % (ln["emotion"], (". " + note) if note else ""))
        out.append("   File: %s.wav" % ln["id"])
        out.append("")
    text = "\n".join(out).rstrip() + "\n"
    open(os.path.join(OUT, "lines_%s.txt" % first), "w", encoding="utf-8").write(text)
    everything.append(text)
open(os.path.join(OUT, "All_lines.txt"), "w", encoding="utf-8").write(("\n" + "=" * 60 + "\n\n").join(everything))
print("wrote", ", ".join("lines_%s.txt" % c["name"].split()[0] for c in data), "and All_lines.txt")
