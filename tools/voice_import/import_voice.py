"""Turns raw voice recordings into the game's voice clips.

    python tools/voice_import/import_voice.py <recordings dir> <script .txt> <char id>

<recordings dir>  folders of .wav files named after the line ids
                  (amara_intro_01.wav; any case, any sub-folders)
<script .txt>     the plain-text voice script (docs/voice/lines_<name>.txt
                  layout: "12. line text" then "File: <id>.wav")
<char id>         succubus, mermaid, slime or dryad

Each recording usually holds several takes of the same line. This finds the
takes (pocketsphinx lines the known text up against the audio), keeps the
LAST take, trims the silence around it, evens out the loudness (-18 LUFS)
and writes audio/voice/<char id>/<id>.ogg. It prints one row per clip; a
clip far longer or shorter than expected is flagged with "CHECK".

To use a different take, or fix a cut, put the seconds in takes.json next
to this script: {"amara_ch1_01": [12.9, 17.8]} (start and end, in the
original .wav). Those always win.

Needs: ffmpeg on PATH, and `pip install pocketsphinx` (it ships its own
English model, nothing else to download).
"""
import glob
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
SILENCE = "silencedetect=noise=-48dB:d=0.35"


def read_script(path):
    lines, cur = {}, None
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*\d+\.\s+(.*)", line)
        if m:
            cur = m.group(1).strip()
            continue
        m = re.match(r"\s*File:\s*(\S+)\.wav", line)
        if m and cur:
            lines[m.group(1).lower()] = cur
            cur = None
    return lines


def speech_segments(wav):
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", wav, "-af", SILENCE, "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    h, m, s = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err).groups()
    dur = int(h) * 3600 + int(m) * 60 + float(s)
    segs, cur, in_sil = [], 0.0, False
    for kind, t in re.findall(r"silence_(start|end): ([\d.]+)", err):
        t = float(t)
        if kind == "start":
            if t - cur > 0.08:
                segs.append([cur, t])
            in_sil = True
        else:
            cur, in_sil = t, False
    if not in_sil and dur - cur > 0.08:
        segs.append([cur, dur])
    return [x for x in segs if x[1] - x[0] > 0.12], dur


def find_takes(wav, text, words_in_dict, tmp):
    """[[start, end], ...] for each take, from a grammar of the line repeated."""
    from pocketsphinx import Decoder
    words = [w for w in re.sub(r"[^a-z' ]", " ", text.lower().replace("-", " ")).split() if w in words_in_dict]
    if not words:
        return []
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", wav, "-af", "dynaudnorm=f=150:g=15,highpass=f=80",
                          "-ar", "16000", "-ac", "1", "-f", "s16le", "-"], capture_output=True).stdout
    gram = os.path.join(tmp, "line.jsgf")
    with open(gram, "w") as f:
        f.write("#JSGF V1.0;\ngrammar g;\npublic <s> = <line>+;\n<line> = " + " ".join(words) + ";\n")
    d = Decoder(jsgf=gram, samprate=16000, loglevel="FATAL")
    d.start_utt()
    d.process_raw(raw, full_utt=True)
    d.end_utt()
    if d.hyp() is None:
        return []
    seg = [(s.start_frame / 100, s.end_frame / 100) for s in d.seg()
           if s.word not in ("<s>", "</s>", "<sil>", "[NOISE]")]
    return [[seg[i][0], seg[i + len(words) - 1][1]] for i in range(0, len(seg) - len(words) + 1, len(words))]


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    rec_dir, script, char_id = sys.argv[1:]
    from pocketsphinx import get_model_path
    words_in_dict = {l.split()[0].split("(")[0] for l in open(os.path.join(get_model_path(), "en-us", "cmudict-en-us.dict"))}
    texts = read_script(script)
    manual_path = os.path.join(HERE, "takes.json")
    manual = json.load(open(manual_path)) if os.path.exists(manual_path) else {}
    out_dir = os.path.join(ROOT, "audio", "voice", char_id)
    os.makedirs(out_dir, exist_ok=True)
    wavs = sorted(glob.glob(os.path.join(rec_dir, "**", "*.wav"), recursive=True), key=lambda p: os.path.basename(p).lower())
    with tempfile.TemporaryDirectory() as tmp:
        for wav in wavs:
            key = os.path.basename(wav).lower()[:-4]
            text = texts.get(key)
            if text is None:
                print(f"{key:22s} SKIPPED: not in the script")
                continue
            segs, dur = speech_segments(wav)
            if not segs:
                print(f"{key:22s} SKIPPED: silent")
                continue
            if key in manual:
                a, b = manual[key]
                how = "takes.json"
            else:
                takes = find_takes(wav, text, words_in_dict, tmp)
                if takes:
                    a, b = takes[-1]
                    how = f"take {len(takes)}/{len(takes)}"
                else:
                    # Couldn't line the text up: the last run of speech after
                    # a pause of 2.5 s or more.
                    i = len(segs) - 1
                    while i > 0 and segs[i][0] - segs[i - 1][1] < 2.5:
                        i -= 1
                    a, b = segs[i][0], segs[-1][1]
                    how = "after last long pause"
            # Snap to the speech around it, so no word is clipped.
            inside = [x for x in segs if x[1] > a - 0.25 and x[0] < b + 0.25]
            start = max(0.0, min([a] + [x[0] for x in inside]) - 0.12)
            end = min(dur, max([b] + [x[1] for x in inside]) + 0.25)
            length = end - start
            trim = f"atrim={start:.3f}:{end:.3f},asetpts=PTS-STARTPTS,highpass=f=70"
            err = subprocess.run(["ffmpeg", "-hide_banner", "-i", wav, "-af", trim + ",loudnorm=I=-18:TP=-1.5:LRA=11:print_format=json",
                                  "-f", "null", "-"], capture_output=True, text=True).stderr
            j = json.loads(err[err.rindex("{"):])
            norm = (f"loudnorm=I=-18:TP=-1.5:LRA=11:measured_I={j['input_i']}:measured_TP={j['input_tp']}"
                    f":measured_LRA={j['input_lra']}:measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true")
            fades = f"afade=t=in:d=0.03,afade=t=out:st={max(0.0, length - 0.1):.3f}:d=0.1"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-af", ",".join([trim, norm, fades]),
                            "-ar", "48000", "-ac", "1", "-c:a", "libvorbis", "-q:a", "6",
                            os.path.join(out_dir, key + ".ogg")], check=True)
            expect = len(text) * 0.095  # about how long she takes over a line this long
            flag = "  CHECK" if not (0.5 * expect < length < 1.9 * expect) else ""
            print(f"{key:22s} {how:22s} {start:6.2f}-{end:6.2f}s ({length:4.1f}s){flag}")


if __name__ == "__main__":
    main()
