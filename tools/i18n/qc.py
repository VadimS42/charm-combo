"""Quality control for every translation (round 52).

    python3 tools/i18n/qc.py            # all languages
    python3 tools/i18n/qc.py fr uk      # some

Checks each translations/<locale>.po against translations/keys.json:
  coverage      every English piece has a translation
  placeholders  %d / %s counts match the English
  numbers       numbers in the English (150, 2000, 24...) are in the translation
  symbols       ⭐ ▸ ← x%d kept (◂ → count as ▸ ← in right-to-left Arabic)
  names         the girls' names appear wherever the English names them
  terms         an item's name is the same everywhere in a language
  english       leftover English words in non-Latin languages
  length        short UI labels more than 1.8x longer than the English
  gender        hedged forms like "(-ла)" or "(a)": the protagonist is male
Exit code 0 if nothing but notes; problems are listed per language.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_txt import read_po  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
TR = os.path.join(ROOT, "translations")
LOCALES = ["zh_CN", "hi", "es", "ar", "fr", "bn", "pt_BR", "ru", "id", "ja", "de", "uk"]
NON_LATIN = {"zh_CN", "hi", "ar", "bn", "ru", "ja", "uk"}
RTL = {"ar"}

# Each girl's first name per language (as used in the stories).
NAMES = {
    "Amara": {"zh_CN": "阿玛拉", "hi": "अमारा", "ar": "أمارا", "bn": "আমারা", "ru": "Амар", "ja": "アマラ", "uk": "Амар"},
    "Marina": {"zh_CN": "玛丽娜", "hi": "मरीना", "ar": "مارينا", "bn": "মেরিনা", "ru": "Марин", "ja": "マリーナ", "uk": "Марин"},
    "Opal": {"zh_CN": "欧泊", "hi": "ओपल", "ar": "أوبال", "bn": "ওপাল", "ru": "Опал", "ja": "オパール", "uk": "Опал"},
    "Hazel": {"zh_CN": "黑泽尔", "hi": "हेज़ल", "ar": "هيزل", "bn": "হেজেল", "ru": "Хейзел", "ja": "ヘイゼル", "uk": "Гейзел"},
}
# Lines (by English text, keys renumber) where the English name means something else (Hazel's flower = the hazel tree).
NAME_SKIP = {"Morning in the grove. There's blossom on the east side of the tree that wasn't there last night. Hazels flower in February. It's May."}
# Words that may stay in Latin letters inside non-Latin translations.
LATIN_OK = {"Steam", "Godot", "Engine", "Google", "Play", "Ctrl", "Enter", "F11", "godot", "log", "Charm", "Combo",
            "L", "T", "A", "H", "x", "QA", "OK", "Mega", "Rune", "Millbrook"}
# Item names whose translation should be identical everywhere in a language.
TERMS = ["Time Scroll", "Shuffle Wand", "Love Potion", "Mending Potion", "Item Shop", "Charm Burst"]
GENDER_HEDGES = [r"\(-?л?а\)", r"\(-ла\)", r"\(a\)", r"\(e\)", r"/a\b", r"\(in\)", r"\*in\b", r"·e\b", r"\(ая\)"]


def numbers(s):
    return sorted(re.findall(r"\d+(?:[.,]\d{3})*", s.replace(" ", "").replace(" ", "")))


def norm_num(n):
    return re.sub(r"[.,]", "", n)


def check(loc, keys, en_index):
    po = read_po(os.path.join(TR, loc + ".po"))
    problems, notes = [], []
    term_tr = {}
    for key, en in keys.items():
        tr = po.get(en)
        if not tr:
            if en.strip() not in ("English",) and not re.fullmatch(r"[\W\d%sd]+", en):
                problems.append("untranslated %s: %s" % (key, en[:60]))
            continue
        if en.count("%d") != tr.count("%d") or en.count("%s") != tr.count("%s"):
            problems.append("placeholders %s: %r -> %r" % (key, en[:50], tr[:50]))
        en_n = [norm_num(n) for n in numbers(en)]
        tr_n = [norm_num(n) for n in numbers(tr)]
        missing = [n for n in en_n if n not in tr_n]
        if missing and loc not in ("zh_CN", "ja") or (missing and not all(n in tr for n in missing)):
            if missing:
                notes.append("numbers %s %s: %s | %s" % (key, missing, en[:50], tr[:60]))
        for sym, alt in (("⭐", "⭐"), ("▸", "◂" if loc in RTL else "▸"), ("←", "→" if loc in RTL else "←")):
            if sym in en and alt not in tr and sym not in tr:
                problems.append("symbol %s missing %s: %s" % (sym, key, tr[:50]))
        for name, per in NAMES.items():
            if name in en and key.startswith(("ui-", "amara", "marina", "opal", "hazel")):
                want = per.get(loc, name)
                if want not in tr and en not in NAME_SKIP:
                    notes.append("name %s %s: %s" % (name, key, tr[:60]))
        if loc in NON_LATIN:
            words = [w for w in re.findall(r"[A-Za-z]{2,}", re.sub(r"%[ds]", "", tr)) if w not in LATIN_OK]
            if words:
                notes.append("latin %s %s: %s" % (key, words[:4], tr[:60]))
        elif tr == en and len(en.split()) >= 3:
            notes.append("same as English %s: %s" % (key, en[:60]))
        if key.startswith("ui-") and len(en) <= 24 and len(tr) > max(10, 1.8 * len(en)) and loc not in ("zh_CN", "ja"):
            notes.append("long %s (%d→%d): %s | %s" % (key, len(en), len(tr), en, tr))
        for pat in GENDER_HEDGES:
            if re.search(pat, tr):
                problems.append("gender hedge %s: %s" % (key, tr[:70]))
        for t in TERMS:
            if t == en.strip():
                term_tr[t] = tr
    # Terms: the item's own translation should appear wherever the English uses it.
    for t, ttr in term_tr.items():
        stem = ttr.split()[0] if loc in NON_LATIN or loc in ("fr", "es", "pt_BR", "de", "id") else ttr
        for key, en in keys.items():
            tr = po.get(en)
            if tr and t in en and en.strip() != t and stem.lower()[:5] not in tr.lower():
                notes.append("term %r (%s) not in %s: %s" % (t, ttr, key, tr[:60]))
    return problems, notes


def main():
    keys = json.load(open(os.path.join(TR, "keys.json"), encoding="utf-8"))
    locs = sys.argv[1:] or LOCALES
    total = 0
    for loc in locs:
        problems, notes = check(loc, keys, None)
        total += len(problems)
        print("== %s: %d problems, %d notes" % (loc, len(problems), len(notes)))
        for p in problems:
            print("  PROBLEM " + p)
        for n in notes:
            print("  note    " + n)
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
