"""Collects every English string the player can see, for translation.

    python3 tools/i18n/extract.py

Writes translations/strings_story_<char id>.json (her lines, replies, endings,
quips, gift) and translations/strings_ui.json (text in the game's scripts).
Each is a JSON list of the English strings, in order, without repeats. The
translators fill translations/<locale>/<same name> with {english: translated};
tools/i18n/build_po.py then writes translations/<locale>.po for Godot.
"""
import json
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "translations")
STORY_KEYS = {"t", "label", "text", "title", "tagline", "name", "role", "desc", "beat1_caption", "beat2_caption"}


def story():
    data = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
    out = {}
    for ch in data:
        seen, items = set(), []

        def walk(o, key=None):
            if isinstance(o, dict):
                if o.get("k") == "slot":
                    return  # writer's notes, never shown
                for k, v in o.items():
                    walk(v, k)
            elif isinstance(o, list):
                for v in o:
                    walk(v, key)
            elif isinstance(o, str) and key in STORY_KEYS and o.strip() and o not in seen:
                seen.add(o)
                items.append(o)
        walk({k: v for k, v in ch.items() if k not in ("voice", "pronunciation", "accessory", "sounds")})
        out[ch["id"]] = items
    return out


# Literals that are code, not text: paths, ids, actions, colours, format-only.
SKIP = re.compile(r"^(res|user)://|^#[0-9A-Fa-f]{3,8}$|^[a-z0-9_./|:-]*$|^[A-Z0-9_]+$|^%|^[^A-Za-z]*$|\.(png|ogg|wav|json|gd|tres|po)$")
CALLS = re.compile(r'"((?:[^"\\]|\\.)*)"')


def ui():
    seen, items = set(), []
    for d in ("scripts", "scripts/screens", "autoload"):
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if not f.endswith(".gd"):
                continue
            for line in open(os.path.join(ROOT, d, f), encoding="utf-8"):
                s = line.strip()
                if s.startswith("#") or s.startswith("##"):
                    continue
                if any(w in s for w in ("push_warning", "push_error", "print(", "get_node(", "has_method(", "InputMap", "is_action", "_add_action", "set_meta", "get_meta", "has_meta", "add_theme_", "create_tween", "tween_property", "connect(", "load(", "Image.", "match ", "settings.get(", "settings[\"", "progress.get(", ".get(\"", "begins_with(", "ends_with(")):
                    # still allow obvious UI text on these lines below
                    pass
                for m in CALLS.finditer(s):
                    t = m.group(1).encode().decode("unicode_escape") if "\\" in m.group(1) else m.group(1)
                    if SKIP.search(t) or t in seen:
                        continue
                    if not re.search(r"[A-Za-z]{2}", t):
                        continue
                    if " " not in t and not re.match(r"^[A-Z][a-z]+[.!?]?$", t):
                        continue  # single lower-case words are keys
                    seen.add(t)
                    items.append(t)
    return items


def main():
    os.makedirs(OUT, exist_ok=True)
    for cid, items in story().items():
        json.dump(items, open(os.path.join(OUT, f"strings_story_{cid}.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(cid, len(items))
    items = ui()
    json.dump(items, open(os.path.join(OUT, "strings_ui.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("ui", len(items))


if __name__ == "__main__":
    main()
