"""Rewrites every language's translator files (translations/txt/<locale>/*.txt)
from its .po, so their "@@ key" lines match translations/keys.json again.

Adding or removing English lines renumbers the keys after them (round 53:
Hazel's night scene went into dialogue_hazel.txt). The .po files match by
English text, so the game itself is fine; only the translator's copies drift,
and re-importing a drifted copy would put translations on the wrong lines.

    python3 tools/i18n/make_txt.py                      # after English changes
    python3 tools/i18n/rekey.py [drafts.py ...]         # optional drafts first

A drafts file is a Python file with LOCALES (list of locale codes) and T
(English text -> list of translations in LOCALES order), like
round53_hazel_night.py. Its lines are imported into each .po first.
"""
import glob
import importlib.util
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_txt import read_po, LOCALES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
TR = os.path.join(ROOT, "translations")


def en_files():
    """{file name: [keys in order]} from the English export."""
    out = {}
    for path in sorted(glob.glob(os.path.join(TR, "txt", "en", "*.txt"))):
        keys = [ln[3:].strip() for ln in open(path, encoding="utf-8") if ln.startswith("@@ ")]
        out[os.path.basename(path)] = keys
    return out


def apply_drafts(path, by_en):
    spec = importlib.util.spec_from_file_location("drafts", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    for i, loc in enumerate(mod.LOCALES):
        folder = os.path.join(TR, "txt", loc)
        tmp = os.path.join(folder, "_drafts.txt")
        lines = []
        for en, tr in mod.T.items():
            if en not in by_en:
                print("  not in the game (skipped):", en[:60])
                continue
            assert len(tr) == len(mod.LOCALES), en
            assert en.count("%") == tr[i].count("%"), (loc, en)
            lines += ["@@ " + by_en[en], tr[i]]
        open(tmp, "w", encoding="utf-8").write("\n".join(lines) + "\n")
        subprocess.run([sys.executable, os.path.join(HERE, "import_txt.py"), loc, tmp], check=True,
                       stdout=subprocess.DEVNULL)
        os.remove(tmp)


def header(path, fallback):
    """The comment lines at the top of an existing translated file."""
    if not os.path.exists(path):
        return [fallback]
    head = []
    for ln in open(path, encoding="utf-8"):
        if ln.startswith("@@"):
            break
        head.append(ln.rstrip("\n"))
    while head and head[-1] == "":
        head.pop()
    return head or [fallback]


def main():
    keys = json.load(open(os.path.join(TR, "keys.json"), encoding="utf-8"))
    by_en = {}
    for k, v in keys.items():
        by_en.setdefault(v, k)
    for d in sys.argv[1:]:
        print("drafts:", d)
        apply_drafts(d, by_en)
    files = en_files()
    for loc in LOCALES:
        po = read_po(os.path.join(TR, loc + ".po"))
        folder = os.path.join(TR, "txt", loc)
        os.makedirs(folder, exist_ok=True)
        report = []
        for name, file_keys in files.items():
            path = os.path.join(folder, name)
            out = header(path, "# %s — %s" % (name, loc))
            n = 0
            for k in file_keys:
                tr = po.get(keys.get(k, ""))
                if tr:
                    out += ["@@ " + k, tr]
                    n += 1
            open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
            report.append("%s %d/%d" % (name.replace(".txt", "").replace("dialogue_", ""), n, len(file_keys)))
        print("%-6s %s" % (loc, ", ".join(report)))


if __name__ == "__main__":
    main()
