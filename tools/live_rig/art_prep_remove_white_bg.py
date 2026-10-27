"""Charm Combo art prep: character art drawn on a white page -> transparent
PNGs for art/characters/<id>/ (first used for Hazel, round 18).

Usage: python3 -I process.py <src dir> <out dir>
  src: neutral/happy/shy/surprised/teasing/sad/angry.png (waist-up busts on a
       white page, same canvas) and optionally main.png (her full figure)
  out: the same names, transparent: busts aligned to neutral's body position,
       trimmed to one shared canvas, 1000 px tall; main.png trimmed, its left
       edge faded (for art that runs off the page there), 1000 px tall.
Needs numpy, scipy, opencv-python, pillow. Check the results over a dark
background: enclosed white gaps vs. highlights are told apart heuristically.
"""
import sys, os, json
import numpy as np
import cv2
from PIL import Image
from scipy import ndimage as ndi

EXPRS = ["neutral", "happy", "shy", "surprised", "teasing", "sad", "angry"]
BUST_H = 1000      # final height of the expression busts (about Marina's 800x1000)
MAIN_H = 1000      # final height of the main (full-body) sprite (shown 575 px tall)
BAND = 5           # px of anti-aliased fade between the art and the white page


def remove_white(rgb, speck_x=None):
    """Alpha mask for a drawing on a white page. Background = near-white
    regions touching the border, plus enclosed near-white gaps (between hair
    strands, under the branch) — told apart from highlights (eye shine, hair
    gloss) by what surrounds them: gaps are walled in by line art or mid-tone
    hair, highlights sit inside light colors."""
    a = rgb.astype(np.int16)
    H, W = a.shape[:2]
    mn = a.min(axis=2)
    mx = a.max(axis=2)
    lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    cand = (mn >= 246) & ((mx - mn) <= 8)
    lab, n = ndi.label(cand)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.zeros((H, W), bool)
    log = {"removed": [], "kept": []}
    for i, sl in enumerate(ndi.find_objects(lab)):
        lid = i + 1
        if sl is None:
            continue
        if lid in border:
            bg[sl] |= lab[sl] == lid
            continue
        y0, y1 = max(0, sl[0].start - 6), min(H, sl[0].stop + 6)
        x0, x1 = max(0, sl[1].start - 6), min(W, sl[1].stop + 6)
        m = lab[y0:y1, x0:x1] == lid
        size = int(m.sum())
        ring = ndi.binary_dilation(m, iterations=4) & ~ndi.binary_dilation(m, iterations=1)
        L = lum[y0:y1, x0:x1][ring]
        ring_lum = float(L.mean()) if L.size else 255.0
        dark = float((L < 90).mean()) if L.size else 0.0
        info = (size, (x0 + 6, y0 + 6, x1 - 6, y1 - 6), round(ring_lum), round(dark, 2))
        cx = (x0 + x1) / 2.0
        outside_face = speck_x is not None and (cx < speck_x[0] or cx > speck_x[1])
        if (size >= 300 and ring_lum < 210) or ring_lum < 130 or dark >= 0.5 or outside_face:
            bg[y0:y1, x0:x1] |= m
            log["removed"].append(info)
        else:
            log["kept"].append(info)
    # Anti-aliased edge: the art fades from its outline to white over ~5 px.
    # For each pixel in that band, take the color of the nearest solid pixel
    # (the outline itself, or the fill where there's no outline) and work out
    # how much of it is there over white — so the edge keeps its own color and
    # no pale rim shows on dark scenes.
    c = rgb.astype(np.float32) / 255.0
    dist = ndi.distance_transform_edt(~bg)
    core = (~bg) & ((dist > BAND) | (lum < 100))
    _, (iy, ix) = ndi.distance_transform_edt(~core, return_indices=True)
    F = c[iy, ix]
    band = (~bg) & (~core)
    d = 1.0 - F                       # white minus foreground
    num = ((1.0 - c) * d).sum(axis=2)
    den = (d * d).sum(axis=2)
    a_lin = np.where(den > 1e-4, num / np.maximum(den, 1e-4), 1.0 - c.min(axis=2))
    a_band = np.clip(a_lin, 0.0, 1.0)
    alpha = np.where(bg, 0.0, np.where(band, a_band, 1.0)).astype(np.float32)
    out_c = np.where(band[..., None], F, c)
    out_c = np.where(bg[..., None], 0.0, out_c)
    rgba = np.dstack([out_c, alpha])
    return (rgba * 255.0 + 0.5).astype(np.uint8), log


def body_shift(ref_gray, gray):
    """How far this expression's body sits from neutral's (shoulders/torso:
    the bottom quarter of the page)."""
    H, W = ref_gray.shape[:2]
    x0, y0, x1, y1 = int(W * 0.08), int(H * 0.74), int(W * 0.92), int(H * 0.998)
    A = ref_gray[y0:y1, x0:x1].astype(np.float32)
    B = gray[y0:y1, x0:x1].astype(np.float32)
    win = cv2.createHanningWindow((A.shape[1], A.shape[0]), cv2.CV_32F)
    (dx, dy), _ = cv2.phaseCorrelate(A, B, win)
    return dx, dy


def translate(rgba, dx, dy):
    H, W = rgba.shape[:2]
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(rgba, M, (W, H), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))


def bbox(alpha, thresh=8):
    ys, xs = np.where(alpha > thresh)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def resize_rgba(rgba, h):
    im = Image.fromarray(rgba, "RGBA").convert("RGBa")  # premultiplied
    w = round(im.width * h / im.height)
    return im.resize((w, h), Image.LANCZOS).convert("RGBA")


def feather_left(rgba, px):
    """Fade the left edge out (the branch runs off the page there)."""
    out = rgba.copy()
    ramp = np.clip(np.arange(px, dtype=np.float32) / px, 0, 1)
    ramp = ramp * ramp * (3 - 2 * ramp)  # smoothstep
    out[:, :px, 3] = (out[:, :px, 3].astype(np.float32) * ramp[None, :]).astype(np.uint8)
    return out


def main(src, dst):
    os.makedirs(dst, exist_ok=True)
    report = {}
    # --- expressions: cut out, align bodies to neutral, one shared crop
    grays = {e: cv2.cvtColor(np.asarray(Image.open(os.path.join(src, e + ".png")).convert("RGB")), cv2.COLOR_RGB2GRAY) for e in EXPRS}
    cut = {}
    for e in EXPRS:
        rgb = np.asarray(Image.open(os.path.join(src, e + ".png")).convert("RGB"))
        # Tiny white specks well outside the face are page showing between
        # hair strands, not eye shine (the face sits in the middle ~half).
        rgba, log = remove_white(rgb, speck_x=(rgb.shape[1] * 0.28, rgb.shape[1] * 0.77))
        dx, dy = (0.0, 0.0) if e == "neutral" else body_shift(grays["neutral"], grays[e])
        if e != "neutral":
            rgba = translate(rgba, -dx, -dy)
        cut[e] = rgba
        report[e] = {"shift": [round(dx, 1), round(dy, 1)], "removed": len(log["removed"]), "kept": log["kept"], "removed_list": log["removed"]}
    boxes = [bbox(cut[e][..., 3]) for e in EXPRS]
    x0 = min(b[0] for b in boxes)
    x1 = max(b[2] for b in boxes)
    top = min(b[1] for b in boxes)
    bottom = min(b[3] for b in boxes)   # no transparent strip under any of them
    H = bottom - top
    head_room = int(H * 0.06)
    side = 24
    for e in EXPRS:
        canvas = np.zeros((H + head_room, x1 - x0 + 2 * side, 4), np.uint8)
        canvas[head_room:, side:side + (x1 - x0)] = cut[e][top:bottom, x0:x1]
        out = resize_rgba(canvas, BUST_H)
        out.save(os.path.join(dst, e + ".png"), optimize=True)
        report[e]["size"] = out.size
    # --- main sprite: cut out, trim, soften the cut-off branch on the left
    if not os.path.exists(os.path.join(src, "main.png")):
        print(json.dumps(report, indent=1, default=str))
        return
    rgb = np.asarray(Image.open(os.path.join(src, "main.png")).convert("RGB"))
    rgba, log = remove_white(rgb)
    bx0, by0, bx1, by1 = bbox(rgba[..., 3])
    rgba = rgba[by0:by1, bx0:bx1]
    rgba = feather_left(rgba, 260)
    out = resize_rgba(rgba, MAIN_H)
    out.save(os.path.join(dst, "main.png"), optimize=True)
    report["main"] = {"size": out.size, "removed": len(log["removed"]), "kept": log["kept"], "removed_list": log["removed"], "crop": [bx0, by0, bx1, by1]}
    print(json.dumps(report, indent=1, default=str))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
