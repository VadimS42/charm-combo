"""Cuts voice clips out of long recordings by hand-picked times (round 43).

    python tools/voice_import/cut_takes.py <recordings dir> <cuts .json> <char id>

For a session recorded as a few long files, many lines per file, instead of
one .wav per line (Opal). <cuts .json> is {"opal_intro_01": ["L01-14.wav",
2.38, 5.44], ...}: the file in <recordings dir> (any audio ffmpeg reads) and
the start and end of the take in seconds. Each clip gets a little air either
side, the same loudness as the others (-18 LUFS) and short fades, and is
written to audio/voice/<char id>/<id>.ogg. Find the takes with Whisper (see
check_clips.py), then run check_clips.py on the result.
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def cut(src, start, end, out):
    start = max(0.0, start - 0.25)
    end = end + 0.3
    length = end - start
    trim = f"atrim={start:.3f}:{end:.3f},asetpts=PTS-STARTPTS,highpass=f=70"
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", src, "-af", trim + ",loudnorm=I=-18:TP=-1.5:LRA=11:print_format=json",
                          "-f", "null", "-"], capture_output=True, text=True).stderr
    j = json.loads(err[err.rindex("{"):])
    norm = (f"loudnorm=I=-18:TP=-1.5:LRA=11:measured_I={j['input_i']}:measured_TP={j['input_tp']}"
            f":measured_LRA={j['input_lra']}:measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true")
    fades = f"afade=t=in:d=0.04,afade=t=out:st={max(0.0, length - 0.15):.3f}:d=0.15"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-af", ",".join([trim, norm, fades]),
                    "-ar", "48000", "-ac", "1", "-c:a", "libvorbis", "-q:a", "6", out], check=True)
    return length


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    rec_dir, cuts_path, char_id = sys.argv[1:]
    cuts = json.load(open(cuts_path, encoding="utf-8"))
    out_dir = os.path.join(ROOT, "audio", "voice", char_id)
    os.makedirs(out_dir, exist_ok=True)
    for key, (name, a, b) in cuts.items():
        length = cut(os.path.join(rec_dir, name), a, b, os.path.join(out_dir, key + ".ogg"))
        print(f"{key:22s} {name:14s} {a:7.2f}-{b:7.2f}s ({length:4.1f}s)")


if __name__ == "__main__":
    main()
