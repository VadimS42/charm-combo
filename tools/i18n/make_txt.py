"""Writes the game's text as plain .txt files for translators.

    python3 tools/i18n/make_txt.py

translations/txt/en/
  dialogue_amara.txt, dialogue_marina.txt, dialogue_opal.txt,
  dialogue_hazel.txt   each girl's lines, replies, endings, quips, gift
  interface.txt        menus, buttons, tips, achievements, the shop

Every piece of text sits under its own "@@ <key>" line. A translator replaces
only the text under each @@ line and keeps every @@ line exactly as it is.
tools/i18n/import_txt.py reads the translated files back.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract  # noqa: E402

ROOT = extract.ROOT
OUT = os.path.join(ROOT, "translations", "txt", "en")
NAMES = {"succubus": "amara", "mermaid": "marina", "slime": "opal", "dryad": "hazel"}

HEADER = """# Charm Combo: {what}
#
# HOW TO TRANSLATE THIS FILE
# - Translate the text under each "@@" line into the language you were asked
#   for (Russian, or Simplified Chinese). Write ONLY the translation there.
# - Keep every "@@ ..." line exactly as it is (the game finds the text by it).
# - Keep %d and %s where they are (the game puts numbers and names there).
# - Keep the names the same everywhere: Amara Duskrose, Marina Waverly, Opal,
#   Hazel Mossgrove, Duskhaven (transliterate them once and stay consistent).
# - An 18+ romance with dry humour; keep the tone, not word-for-word.
# - Lines starting with "#" are notes; they can be left out.
"""

# UI strings that are for developers only (logs, file errors, placeholder
# tags, key names): not worth translating.
UI_SKIP_PREFIX = ("CharacterData", "GameState", "Platform", "Charm Combo %s", "characters.json",
                  "Godot/", "godot/", "relaunching", "Steam not", "Steam connected", "GodotSteam",
                  "not used", "itch.io build")
UI_SKIP = {"Camera", "Motes", "Enter", "Backspace", "Start", "Esc", "Arrows", "Right stick", "RB (hold)",
           "Ctrl (hold)", "Steam", "TEST MODE", "Art placeholder", "Frame placeholder",
           "Location art · placeholder", "Epilogue art · placeholder", "Ending CG · placeholder art",
           "The dialogue file has a mistake in it", "Store page address not set yet (Platform.STORE_URL).",
           " should start with [ and end with ] (a list of the four characters).", "\n    License: ",
           "This game uses Godot Engine, available under the following license:", "Third-party components",
           "License texts", "Bundled fonts", "💞 Charm Combo", "Charm Combo", "Frame",
           "\nTest build: using your edited characters.json from the game's folder."}
UI_SKIP_STARTS = ("Open that file, fix the line",)

# Pieces the game builds at runtime (UITheme.t()) that the extractor can't see.
UI_EXTRA = ["%d / %d unlocked", "%d / %d endings found", "Click to view.", "%d pts — rough start...",
            "%d / %d pts", "%d pts...", "Ending: %s", "Give her the %s", "(You need %d more stars.)",
            "Stars come from clearing chapters: 15 for a girl's first and 5 more for each one after it.",
            "Running out of moves still pays 1 star for every 100 points you scored (at least 3).",
            "The top row is used during a chapter; the bottom row kicks in on its own when your next chapter starts.",
            "Language", "The game's text. Voices stay in English."]


def ui_strings():
    items = []
    for s in extract.ui() + UI_EXTRA:
        if s in items or s in UI_SKIP or s.startswith(UI_SKIP_PREFIX) or s.startswith(UI_SKIP_STARTS):
            continue
        if s.startswith("Stars come from clearing") and s.endswith(" "):
            continue  # the old three-piece sentence
        if s.startswith("Running out of moves still pays") and s.endswith(" "):
            continue
        items.append(s)
    return items


def write(path, what, keyprefix, items):
    with open(path, "w", encoding="utf-8") as f:
        f.write(HEADER.format(what=what))
        for i, s in enumerate(items, 1):
            f.write("\n@@ %s-%04d\n%s\n" % (keyprefix, i, s))
    return len(items)


def main():
    os.makedirs(OUT, exist_ok=True)
    keymap = {}
    for cid, items in extract.story().items():
        name = NAMES.get(cid, cid)
        n = write(os.path.join(OUT, "dialogue_%s.txt" % name), "%s's dialogue" % name.capitalize(), name, items)
        keymap.update({"%s-%04d" % (name, i): s for i, s in enumerate(items, 1)})
        print("dialogue_%s.txt: %d pieces, %d words" % (name, n, sum(len(s.split()) for s in items)))
    ui = ui_strings()
    write(os.path.join(OUT, "interface.txt"), "menus, buttons, tips and achievements", "ui", ui)
    keymap.update({"ui-%04d" % i: s for i, s in enumerate(ui, 1)})
    print("interface.txt: %d pieces, %d words" % (len(ui), sum(len(s.split()) for s in ui)))
    # key -> English, so the translated files can be matched back.
    json.dump(keymap, open(os.path.join(ROOT, "translations", "keys.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
