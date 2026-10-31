"""Listens to every voice clip and checks it says the line on screen (round 38).

    python tools/voice_import/check_clips.py <whisper model dir> <char id> [--all]

<whisper model dir>  a sherpa-onnx Whisper model, e.g. sherpa-onnx-whisper-small.en
                     from https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models
                     (pip install sherpa-onnx)
<char id>            succubus, mermaid, slime or dryad

Transcribes audio/voice/<char id>/*.ogg with Whisper and compares the words
with the line's "t" in data/characters.json (case, punctuation and spelling
of numbers ignored). Prints every clip that differs, with the words missing
from the clip (-) and the words the clip has that the text doesn't (+), and
a match score; --all prints the ones that match too. Sounds (laughs, sighs)
are skipped.
"""
import difflib
import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NUMBERS = {"two hundred": "200", "three hundred": "300", "forty": "40", "twenty": "20", "nine": "9",
           "six": "6", "five": "5", "three": "3", "two": "2", "one": "1", "four": "4"}


def words(s):
    s = s.lower().replace("’", "'")
    s = re.sub(r"[^a-z0-9' ]+", " ", s)
    for w, n in NUMBERS.items():
        s = re.sub(r"\b%s\b" % w, n, s)
    s = s.replace("'", "")
    for w, n in SAME.items():
        s = re.sub(r"\b%s\b" % w, n, s)
    return s.split()


# Things Whisper writes differently that aren't a different line: spoken
# contractions, American spellings, names and fillers.
SAME = {"gonna": "going to", "wanna": "want to", "mom": "mum", "grand": "gran", "grands": "grans",
        "marie": "mari", "rung": "wrung", "boat house": "boathouse", "ooh": "oh", "mmm": "mm",
        "hmm": "", "hm": "", "uh": "", "um": "", "older": "alder",
        "photosynthesizing": "photosynthesising"}


def line_texts(char_id):
    data = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
    chars = data if isinstance(data, list) else data["characters"]
    ch = [c for c in chars if c["id"] == char_id][0]
    out = {}

    def walk(o):
        if isinstance(o, dict):
            if isinstance(o.get("id"), str) and "t" in o and o.get("kind") is None:
                out[o["id"]] = o["t"]
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk({k: v for k, v in ch.items() if k != "sounds"})
    return out


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    model, char_id = sys.argv[1], sys.argv[2]
    show_all = "--all" in sys.argv
    import sherpa_onnx
    pre = os.path.basename(model.rstrip("/")).replace("sherpa-onnx-whisper-", "")
    rec = sherpa_onnx.OfflineRecognizer.from_whisper(
        encoder=os.path.join(model, pre + "-encoder.int8.onnx"),
        decoder=os.path.join(model, pre + "-decoder.int8.onnx"),
        tokens=os.path.join(model, pre + "-tokens.txt"), language="en", task="transcribe", num_threads=4)
    texts = line_texts(char_id)
    bad = 0
    clips = sorted(glob.glob(os.path.join(ROOT, "audio", "voice", char_id, "*.ogg")))
    for clip in clips:
        key = os.path.basename(clip)[:-4]
        if key not in texts:
            continue
        pcm = subprocess.run(["ffmpeg", "-v", "quiet", "-i", clip, "-ac", "1", "-ar", "16000", "-f", "f32le", "-"],
                             capture_output=True).stdout
        import array
        samples = array.array("f", pcm)
        s = rec.create_stream()
        s.accept_waveform(16000, samples)
        rec.decode_stream(s)
        heard = s.result.text.strip()
        want, got = words(texts[key]), words(heard)
        score = difflib.SequenceMatcher(None, want, got).ratio()
        diff = [op for op in difflib.ndiff(want, got) if op[0] in "+-"]
        if diff:
            bad += 1
        if diff or show_all:
            print(f"{key:20s} {score:4.0%}  text : {texts[key]}")
            print(f"{'':26s}heard: {heard}")
            if diff:
                print(f"{'':26s}{' '.join(d.replace(' ', '') for d in diff)}")
    print(f"{len(clips)} clips, {bad} differ from their text")


if __name__ == "__main__":
    main()
