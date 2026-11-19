"""Imports the drafted interface translations in round50_strings.py into every
language's .po, then rewrites each language's translations/txt/<locale>/
interface.txt from its .po so its "@@ ui-…" keys match translations/keys.json
again (adding strings renumbers them; re-importing an old file would then put
translations on the wrong lines).

    python3 tools/i18n/make_txt.py        # first, after English text changed
    python3 tools/i18n/apply_drafts.py
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from round50_strings import T, LOCALES  # noqa: E402
from import_txt import read_po  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
TR = os.path.join(ROOT, "translations")


def main():
    keys = json.load(open(os.path.join(TR, "keys.json"), encoding="utf-8"))
    by_en = {v: k for k, v in keys.items()}
    missing = [e for e in T if e not in by_en]
    if missing:
        print("Not in the game any more (skipped):", missing)
    for i, loc in enumerate(LOCALES):
        folder = os.path.join(TR, "txt", loc)
        os.makedirs(folder, exist_ok=True)
        draft = os.path.join(folder, "ui_drafts.txt")
        lines = ["# Machine-drafted interface strings (round 50): have a native speaker check them."]
        for en, tr in T.items():
            if en not in by_en:
                continue
            assert en.count("%") == tr[i].count("%"), (loc, en)
            lines += ["@@ " + by_en[en], tr[i]]
        open(draft, "w", encoding="utf-8").write("\n".join(lines) + "\n")
        subprocess.run([sys.executable, os.path.join(HERE, "import_txt.py"), loc, draft], check=True,
                       stdout=subprocess.DEVNULL)
        # Rewrite interface.txt (the whole interface, current keys) from the .po.
        po = read_po(os.path.join(TR, loc + ".po"))
        iface = os.path.join(folder, "interface.txt")
        head = open(iface, encoding="utf-8").readline().rstrip("\n") if os.path.exists(iface) \
            else "# Interface — %s" % loc
        out = [head]
        n = 0
        for k, v in keys.items():
            if k.startswith("ui-") and po.get(v):
                out += ["@@ " + k, po[v]]
                n += 1
        open(iface, "w", encoding="utf-8").write("\n".join(out) + "\n")
        os.remove(draft)
        untranslated = [v for k, v in keys.items() if k.startswith("ui-") and not po.get(v)]
        print("%-6s interface: %d translated, %d still English %s" % (loc, n, len(untranslated), untranslated[:3]))


if __name__ == "__main__":
    main()
