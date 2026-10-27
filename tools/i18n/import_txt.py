"""Reads translated .txt files (made by make_txt.py) into the game.

    python3 tools/i18n/import_txt.py ru  path/to/dialogue_amara.txt path/to/interface.txt ...
    python3 tools/i18n/import_txt.py zh_CN  path/to/*.txt

Matches each "@@ <key>" block to its English text (translations/keys.json),
merges them into translations/<locale>.po (keeping what's already there), and
reports keys it couldn't find and lines whose %d / %s don't match the English.
Anything not translated stays English in the game.
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
TR = os.path.join(ROOT, "translations")
LOCALES = {"ru": "Russian", "zh_CN": "Chinese (Simplified)"}


def parse_txt(path):
    text = open(path, encoding="utf-8-sig").read().replace("\r\n", "\n")
    out, key, buf = {}, None, []

    def flush():
        if key is not None:
            body = "\n".join(buf).strip("\n")
            if body.strip():
                out[key] = body
    for line in text.split("\n"):
        m = re.match(r"^\s*@@\s*([A-Za-z]+-\d{4})\s*$", line)
        if m:
            flush()
            key, buf = m.group(1), []
        elif key is not None and not line.startswith("#"):
            buf.append(line)
    flush()
    return out


def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_unescape(s):
    return re.sub(r'\\(.)', lambda m: {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(m.group(1), m.group(1)), s)


def read_po(path):
    if not os.path.exists(path):
        return {}
    out, cur, field = {}, {"msgid": "", "msgstr": ""}, None
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        m = re.match(r'^(msgid|msgstr) "(.*)"$', line)
        if m:
            if m.group(1) == "msgid" and cur["msgid"]:
                out[cur["msgid"]] = cur["msgstr"]
                cur = {"msgid": "", "msgstr": ""}
            field = m.group(1)
            cur[field] = po_unescape(m.group(2))
        elif line.startswith('"') and field:
            cur[field] += po_unescape(line[1:-1])
    if cur["msgid"]:
        out[cur["msgid"]] = cur["msgstr"]
    return {k: v for k, v in out.items() if k and v}


def write_po(path, locale, entries):
    with open(path, "w", encoding="utf-8") as f:
        f.write('msgid ""\nmsgstr ""\n"Language: %s\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n' % locale)
        for k in sorted(entries):
            f.write('\nmsgid "%s"\nmsgstr "%s"\n' % (po_escape(k), po_escape(entries[k])))


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in LOCALES:
        sys.exit(__doc__)
    locale, files = sys.argv[1], sys.argv[2:]
    keys = json.load(open(os.path.join(TR, "keys.json"), encoding="utf-8"))
    po_path = os.path.join(TR, locale + ".po")
    entries = read_po(po_path)
    added, unknown, warn = 0, [], []
    for f in files:
        for key, text in parse_txt(f).items():
            en = keys.get(key)
            if en is None:
                unknown.append(key)
                continue
            if sorted(re.findall(r"%[ds]", en)) != sorted(re.findall(r"%[ds]", text)):
                warn.append("%s: %%d/%%s don't match the English, skipped" % key)
                continue
            entries[en] = text
            added += 1
    write_po(po_path, locale, entries)
    print("%s: %d pieces read, %d in translations/%s.po of %d in the game" % (LOCALES[locale], added, len(entries), locale, len(keys)))
    if unknown:
        print("Unknown @@ keys (typo, or from an older export):", ", ".join(unknown[:20]))
    for w in warn:
        print(w)
    missing = [k for k, en in keys.items() if en not in entries]
    if missing:
        print("%d pieces still in English, e.g. %s" % (len(missing), ", ".join(missing[:8])))


if __name__ == "__main__":
    main()
