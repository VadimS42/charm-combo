"""Charm Combo: a blink for a character whose eyes are small on screen
(round 42, first used for Amara). Simpler than blink.py: no hair-strand
detection, just skin over the eye and a lid line.

Usage: python3 -I blink_simple.py <eyes.json> <main.png> <out dir>

<eyes.json>: {"offset": [x, y],   where main.png sits on the page the eyes
                                   were measured on (main = page[y:, x:])
              "lash": [r, g, b],  lid line colour
              "eyes": [{"poly": [[x, y], ...],      outline round the open eye
                        "shut": [[x, y], [x, y], [x, y]]}]}   closed lid line
                                   (left corner, lowest point, right corner)
All points in page pixels. Writes into <out dir>:
  blink.png   [half-shut | shut] patches of the eye area
  base.png    a copy of main.png; hair.png and mask.png empty, so LiveSprite
              (with "motion": false) only blinks
  live.json   the blink rect and "motion": false
"""
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

PAD = 10


def fill_from_around(rgb, mask):
    """Fills `mask` with the colours around it, smoothly (skin over the eye)."""
    out = rgb.copy()
    # Only skin outside the eye counts (not lashes, hair or the eye white):
    # light, warm, not grey.
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    skin = (r > 190) & (g > 150) & (r - b > 12) & (r - b < 70)
    known = (~mask & skin).astype(np.float32)
    acc = rgb * known[..., None]
    w = known.copy()
    for sigma in (4, 8, 16, 32):
        a = np.stack([ndi.gaussian_filter(acc[..., c], sigma) for c in range(3)], -1)
        k = ndi.gaussian_filter(w, sigma)[..., None]
        est = a / np.maximum(k, 1e-4)
        out[mask] = est[mask]
        if (k[mask] > 0.05).all():
            break
    return out


def lid(draw_rgb, alpha, pts, closure_y, xs, colour, thick):
    (ax, ay), (mx, my), (bx, by) = pts
    c = np.polyfit([ax, mx, bx], [ay, my, by], 2)
    for x in xs:
        y = np.polyval(c, x) + closure_y
        t = 1.0 - abs((x - mx) / max(1.0, (bx - ax) / 2.0)) * 0.55
        r = max(0.6, thick * t / 2.0)
        yy, xx = np.ogrid[:alpha.shape[0], :alpha.shape[1]]
        d = np.sqrt((xx - x) ** 2 + (yy - y) ** 2)
        cov = np.clip(r + 0.5 - d, 0, 1)
        draw_rgb[:] = draw_rgb * (1 - cov[..., None]) + np.array(colour, np.float32) * cov[..., None]
        alpha[:] = np.maximum(alpha, cov)


def main(cfg_path, main_png, out_dir):
    cfg = json.load(open(cfg_path))
    ox, oy = cfg["offset"]
    lash = cfg.get("lash", [40, 22, 32])
    img = Image.open(main_png).convert("RGBA")
    rgba = np.asarray(img).astype(np.float32)
    eyes = [{"poly": [(x - ox, y - oy) for x, y in e["poly"]],
             "shut": [(x - ox, y - oy) for x, y in e["shut"]]} for e in cfg["eyes"]]
    allp = np.array([p for e in eyes for p in e["poly"]])
    x0, y0 = (allp.min(0) - PAD).astype(int)
    x1, y1 = (allp.max(0) + PAD).astype(int)
    patch = rgba[y0:y1, x0:x1, :3]
    ph, pw = patch.shape[:2]
    frames = []
    for closure in (0.5, 1.0):
        out = patch.copy()
        alpha = np.zeros((ph, pw), np.float32)
        for e in eyes:
            poly = [(x - x0, y - y0) for x, y in e["poly"]]
            m = Image.new("L", (pw, ph), 0)
            ImageDraw.Draw(m).polygon(poly, fill=255)
            mask = np.asarray(m) > 0
            ys = np.array([p[1] for p in poly])
            top, bot = ys.min(), ys.max()
            shut = [(x - x0, y - y0) for x, y in e["shut"]]
            if closure < 1.0:
                # Half-shut: the upper part covered down to halfway.
                cut = top + (bot - top) * 0.55
                yy = np.arange(ph)[:, None]
                mask = mask & (yy <= cut)
            filled = fill_from_around(patch, ndi.binary_dilation(mask, iterations=1))
            cov = np.clip(ndi.gaussian_filter(ndi.binary_dilation(mask, iterations=1).astype(np.float32), 0.8) * 1.3, 0, 1)
            out = out * (1 - cov[..., None]) + filled * cov[..., None]
            alpha = np.maximum(alpha, cov)
            xs = np.arange(min(shut[0][0], shut[2][0]), max(shut[0][0], shut[2][0]) + 1, 0.5)
            # The half-shut lid sits higher than the closed one.
            dy = -(bot - top) * 0.3 if closure < 1.0 else 0.0
            lid(out, alpha, shut, dy, xs, lash, 4.0 if closure < 1.0 else 3.2)
        frames.append((out, alpha))
    os.makedirs(out_dir, exist_ok=True)
    atlas = Image.new("RGBA", (pw * len(frames), ph), (0, 0, 0, 0))
    for i, (o, a) in enumerate(frames):
        atlas.paste(Image.fromarray(np.dstack([o, a * 255]).clip(0, 255).astype(np.uint8), "RGBA"), (i * pw, 0))
    arr = np.asarray(atlas).copy()
    vis = arr[..., 3] > 0
    if vis.any() and not vis.all():
        _, (iy, ix) = ndi.distance_transform_edt(~vis, return_indices=True)
        arr[..., :3] = arr[iy, ix, :3]
    Image.fromarray(arr, "RGBA").save(os.path.join(out_dir, "blink.png"))
    shutil.copy(main_png, os.path.join(out_dir, "base.png"))
    Image.new("RGBA", img.size, (0, 0, 0, 0)).save(os.path.join(out_dir, "hair.png"))
    Image.new("RGBA", img.size, (0, 0, 0, 255)).save(os.path.join(out_dir, "mask.png"))
    live = {"blink_rect": [int(x0), int(y0), int(pw), int(ph)], "blink_frames": 2, "motion": False, "ambient": "none"}
    json.dump(live, open(os.path.join(out_dir, "live.json"), "w"), indent=1)
    print(json.dumps(live))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
