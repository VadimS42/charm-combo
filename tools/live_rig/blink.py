"""Charm Combo: closed-eye frames for a character's blink, painted from the
high-res source art (round 20, first used for Hazel).

Usage: python3 -I blink.py <src page png> <out dir> [--debug <dir>]

For each eye (EYES, in source-page px): finds the open eye (iris, white,
upper lash band) inside a rough outline, paints it shut with skin taken from
around it, and draws the lid line — leaving any hair strands that cross the
eye on top. Writes blink.png: [half-shut | shut] patches of the eye area,
already scaled to the main sprite (CROP_Y / SCALE below), plus blink.json
with where that area sits on the sprite.
"""
import sys, os, json
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

CROP_Y = 112                 # main.png = page[112:, :] scaled by SCALE
SCALE = 1000.0 / 3395.0
EYES = {
    # rough outline around each open eye, generous; corners for the lid line
    # "shut": the closed lid line, inner/outer corner and lowest point (it
    # replaces the lower edge of the open eye, a little flatter)
    "right": {"poly": [(1150, 640), (1172, 612), (1212, 606), (1262, 622), (1278, 648),
                       (1266, 670), (1228, 684), (1186, 678), (1152, 664)],
              "shut": [(1162, 657), (1212, 673), (1260, 653)],
              "outer": "left", "flick": True},
    "left": {"poly": [(1352, 590), (1356, 566), (1392, 546), (1440, 538), (1458, 541),
                      (1467, 556), (1463, 596), (1440, 610), (1400, 612), (1364, 606)],
             "shut": [(1360, 598), (1410, 605), (1463, 562)],
             "outer": "right", "flick": False},   # her own lash wing stays
}
PAD = 14                     # source px around the eyes in the patch
LASH = np.array([74, 50, 44], np.float32)   # lid line colour (her lash brown)


def classify_eye(rgb, poly_m):
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.int16)
    H, S, V = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    iris = (S >= 110) & (V >= 50) & ((H <= 45) | (H >= 245))
    sclera = (V >= 222) & (S <= 32)
    shade = (V >= 120) & (V < 222) & (S < 66) & ((H >= 200) | (H <= 18))
    dark = V < 125
    thick = ndi.binary_opening(dark, structure=np.ones((5, 5)))
    thick = ndi.binary_dilation(thick, iterations=2) & dark
    core = (iris | sclera | shade | thick) & poly_m
    E = ndi.binary_closing(core, structure=np.ones((3, 3)), iterations=3) & poly_m
    E = ndi.binary_fill_holes(E)
    lab, n = ndi.label(E)
    if n > 1:
        sizes = ndi.sum(E, lab, range(1, n + 1))
        E = lab == (1 + int(np.argmax(sizes)))
    skin = (H <= 24) & (S >= 25) & (S < 85) & (V >= 200) & ~E
    blonde = (H >= 20) & (H <= 48) & (S >= 55) & (S < 140) & (V >= 150) & ~E
    return E, skin, blonde


def skin_fill(rgb, E, skin):
    """Smooth skin over E, from skin pixels only (no hair/lash colour)."""
    known = skin & ~E
    unknown = (~known).astype(np.uint8) * 255
    src = np.where(known[..., None], rgb, 0).astype(np.uint8)
    f = cv2.inpaint(src, unknown, 15, cv2.INPAINT_TELEA).astype(np.float32)
    return cv2.GaussianBlur(f, (0, 0), 4.0)


def column_span(E):
    cols = np.where(E.any(axis=0))[0]
    top = np.full(E.shape[1], np.nan)
    bot = np.full(E.shape[1], np.nan)
    for x in cols:
        ys = np.where(E[:, x])[0]
        top[x], bot[x] = ys.min(), ys.max()
    return cols, top, bot


def smooth_curve(xs, ys, s=9):
    k = np.ones(s) / s
    pad = np.pad(ys, s // 2, mode="edge")
    return np.convolve(pad, k, mode="valid")


def draw_lid(canvas_rgb, canvas_a, xs, ys, thick_mid, thick_end, outer, allowed, flick=True):
    """Stroke a lid line through (xs, ys) onto the patch, only where
    `allowed` (so hair strands crossing the eye stay on top)."""
    h, w = allowed.shape
    ss = 4
    big = Image.new("L", (w * ss, h * ss), 0)
    d = ImageDraw.Draw(big)
    n = len(xs)
    for i in range(n - 1):
        t = i / max(1, n - 1)
        # thickest a little toward the outer corner, tapering at both ends
        tt = t if outer == "right" else 1 - t
        prof = np.sin(np.pi * np.clip(tt * 0.85 + 0.1, 0, 1)) ** 0.7
        r = thick_end + (thick_mid - thick_end) * prof
        x0, y0 = xs[i] * ss, ys[i] * ss
        d.ellipse([x0 - r * ss / 2, y0 - r * ss / 2, x0 + r * ss / 2, y0 + r * ss / 2], fill=255)
    if flick:
        # two short lashes off the outer corner
        if outer == "right":
            ex, ey = xs[-1], ys[-1]
            dirs = [(1.0, 0.55), (0.75, 1.0)]
        else:
            ex, ey = xs[0], ys[0]
            dirs = [(-1.0, 0.55), (-0.75, 1.0)]
        for j, (dx, dy) in enumerate(dirs):
            L = 13 - 3 * j
            for k in range(L):
                r = (thick_end + 1.5) * (1 - k / L)
                cx, cy = (ex + dx * k) * ss, (ey + dy * k * 0.9) * ss
                d.ellipse([cx - r * ss / 2, cy - r * ss / 2, cx + r * ss / 2, cy + r * ss / 2], fill=255)
    m = np.asarray(big.resize((w, h), Image.LANCZOS)).astype(np.float32) / 255.0
    m *= allowed
    canvas_rgb[:] = canvas_rgb * (1 - m[..., None]) + LASH * m[..., None]
    canvas_a[:] = np.maximum(canvas_a, m)


def make_frames(page_rgb, debug=None):
    H, W = page_rgb.shape[:2]
    # patch box around both eyes
    allp = np.array([p for e in EYES.values() for p in e["poly"]])
    x0, y0 = allp.min(axis=0) - PAD
    x1, y1 = allp.max(axis=0) + PAD
    # snap to sprite px so the patch lands exactly on the sprite grid
    sx0 = int(np.floor(x0 * SCALE)); sy0 = int(np.floor((y0 - CROP_Y) * SCALE))
    sx1 = int(np.ceil(x1 * SCALE)); sy1 = int(np.ceil((y1 - CROP_Y) * SCALE))
    X0 = int(round(sx0 / SCALE)); Y0 = int(round(sy0 / SCALE)) + CROP_Y
    X1 = int(round(sx1 / SCALE)); Y1 = int(round(sy1 / SCALE)) + CROP_Y
    rgb = page_rgb[Y0:Y1, X0:X1].astype(np.float32)
    ph, pw = rgb.shape[:2]
    frames = []
    for closure in (0.55, 1.0):
        out = rgb.copy()
        alpha = np.zeros((ph, pw), np.float32)
        for name, eye in EYES.items():
            poly = [(x - X0, y - Y0) for x, y in eye["poly"]]
            pm = Image.new("L", (pw, ph), 0)
            ImageDraw.Draw(pm).polygon(poly, fill=255)
            poly_m = np.asarray(pm) > 0
            E, skin, blonde = classify_eye(rgb.astype(np.uint8), poly_m)
            fill = skin_fill(rgb.astype(np.uint8), E, skin)
            cols, top, bot = column_span(E)
            # shut line: a parabola through the three hand-placed points
            (ax, ay), (mx, my), (bx, by) = [(x - X0, y - Y0) for x, y in eye["shut"]]
            shut_c = np.polyfit([ax, mx, bx], [ay, my, by], 2)
            lo, hi = min(ax, bx), max(ax, bx)
            xs = np.arange(int(np.ceil(lo)), int(np.floor(hi)) + 1).astype(np.float32)
            # open lid edge: the top of the eye, smoothed into a parabola too
            tc = np.polyfit(cols.astype(np.float32), top[cols], 2)
            tp = np.polyval(tc, xs)
            sh = np.polyval(shut_c, xs)
            lid = tp + (sh - tp) * closure
            # columns of E outside the corners still get covered down to the line
            ext_x = cols.astype(np.float32)
            ext_lid = np.interp(ext_x, xs, lid)
            cols_all = cols
            yy = np.arange(ph)[:, None]
            lid_full = np.full(pw, -1e9)
            lid_full[cols_all] = ext_lid
            # strand outlines next to the eye stay (so strand tips aren't cut)
            E = E & ~(ndi.binary_dilation(blonde, iterations=2) & (rgb.astype(np.uint8).max(axis=2) < 140))
            if closure >= 1.0:
                cover = E.copy()
            else:
                cover = E & (yy <= lid_full[None, :] + 0.5)
            # soft edge on the cover, a touch past E so no rim of the old eye shows
            grow = ndi.binary_dilation(cover, iterations=2) & ~ndi.binary_dilation(blonde, iterations=1)
            if closure < 1.0:
                grow &= (yy <= lid_full[None, :] + 2.5)
            cov = np.clip(ndi.gaussian_filter(grow.astype(np.float32), 1.0) * 1.15, 0, 1)
            cov = np.maximum(cov, cover.astype(np.float32))
            out = out * (1 - cov[..., None]) + fill * cov[..., None]
            alpha = np.maximum(alpha, cov)
            allowed = ndi.binary_dilation(E, iterations=9) & ~ndi.binary_dilation(blonde, iterations=1)
            allowed = ndi.gaussian_filter(allowed.astype(np.float32), 0.6)
            o_rgb = out
            if closure < 1.0:
                draw_lid(o_rgb, alpha, xs, lid, 12.0, 5.0, eye["outer"], allowed, flick=False)
            else:
                draw_lid(o_rgb, alpha, xs, lid, 8.5, 3.5, eye["outer"], allowed, flick=eye["flick"])
            out = o_rgb
        frames.append((np.clip(out, 0, 255), alpha))
    # scale to sprite px
    sw, sh = sx1 - sx0, sy1 - sy0
    atlas = Image.new("RGBA", (sw * len(frames), sh), (0, 0, 0, 0))
    for i, (o, a) in enumerate(frames):
        rgba = np.dstack([o, a * 255.0]).astype(np.uint8)
        p = Image.fromarray(rgba, "RGBA").convert("RGBa").resize((sw, sh), Image.LANCZOS).convert("RGBA")
        atlas.paste(p, (i * sw, 0))
        if debug:
            full = np.dstack([o, np.full(a.shape, 255.0)]).astype(np.uint8)
            Image.fromarray(full[..., :3]).save(os.path.join(debug, "blink_src_%d.png" % i))
    return atlas, [sx0, sy0, sw, sh]


def main(src, dst, debug=None):
    os.makedirs(dst, exist_ok=True)
    if debug:
        os.makedirs(debug, exist_ok=True)
    page = np.asarray(Image.open(src).convert("RGB"))
    atlas, rect = make_frames(page, debug)
    # transparent pixels take the nearest visible colour (clean filtering)
    arr = np.asarray(atlas).copy()
    vis = arr[..., 3] > 0
    if vis.any() and not vis.all():
        _, (iy, ix) = ndi.distance_transform_edt(~vis, return_indices=True)
        arr[..., :3] = arr[iy, ix, :3]
    Image.fromarray(arr, "RGBA").save(os.path.join(dst, "blink.png"), optimize=True)
    json.dump({"blink_rect": rect, "blink_frames": 2}, open(os.path.join(dst, "blink.json"), "w"))
    print(json.dumps({"blink_rect": rect, "atlas": atlas.size}))


if __name__ == "__main__":
    a = sys.argv[1:]
    dbg = None
    if "--debug" in a:
        i = a.index("--debug"); dbg = a[i + 1]; a = a[:i] + a[i + 2:]
    main(a[0], a[1], dbg)
