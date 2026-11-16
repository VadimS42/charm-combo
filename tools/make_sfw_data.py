"""Writes data/characters_sfw.json, the safe-for-work builds' story (round 46).

    python3 tools/make_sfw_data.py

From data/characters.json:
  - each girl's night scene goes; story.night_sfw, if she has one, takes
    its place (as story.night)
  - each ending's epilogue_sfw / text_sfw / title_sfw replace the originals
  - every line with "sfw": "other text" says that instead (its voice id is
    dropped unless the line has "sfw_id"); every line with "sfw": false goes
The Epic and Android presets ship this file and leave characters.json out
(export_presets.cfg), so no adult text is in those packages. Run it again
whenever characters.json changes, before exporting those builds.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def lines(arr):
    out = []
    for l in arr:
        if isinstance(l, dict) and "sfw" in l:
            if l["sfw"] is False:
                continue
            c = {k: v for k, v in l.items() if k not in ("sfw", "sfw_id", "id")}
            c["t"] = l["sfw"]
            if "sfw_id" in l:
                c["id"] = l["sfw_id"]
            out.append(walk(c))
        else:
            out.append(walk(l))
    return out


def walk(o):
    if isinstance(o, list):
        return lines(o)
    if isinstance(o, dict):
        o = dict(o)
        for k in ("text", "title"):
            if k + "_sfw" in o:
                o[k] = o.pop(k + "_sfw")
        if "epilogue_sfw" in o:
            o["epilogue"] = o.pop("epilogue_sfw")
        return {k: walk(v) for k, v in o.items()}
    return o


def main():
    data = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
    out = []
    for ch in data:
        ch = dict(ch)
        story = dict(ch["story"])
        night = story.pop("night_sfw", None)
        story.pop("night", None)
        if night:
            story["night_sfw"] = night  # read by StoryFlow.night_for() in sfw builds
        ch["story"] = story
        out.append(walk(ch))
    path = os.path.join(ROOT, "data", "characters_sfw.json")
    json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    open(path, "a", encoding="utf-8").write("\n")
    print("wrote data/characters_sfw.json (%d girls)" % len(out))


if __name__ == "__main__":
    main()
