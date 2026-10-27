"""Charm Combo: split a character's main sprite into a "live" rig for the
in-game LiveSprite shader (round 20, first used for Hazel).

Usage: python3 -I rig_live.py <main.png> <out dir> [--debug <dir>]

Writes into <out dir>:
  base.png  the sprite with her free-hanging hair taken out (branch behind
            the hair tips filled in), drawn first, breathing with her body
  hair.png  just the free-hanging hair (plus a little hair continued under
            her arm/thigh, so a sway never opens a gap), swaying on top
  mask.png  R = how much a pixel rises when she breathes in (body/head yes,
            branch no), G = head sway weight, B = "in front of the hair"
            (her arm, dress, thigh: the hair hides behind these), A = how
            freely the hair swings there (less where it lies on the branch)
Coordinates below are for Hazel's 730x1000 main.png; another character needs
her own zones (ZONES) and colour rules (classify()).
"""
import sys, os, json
import numpy as np
import cv2
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

# Free-hanging hair lives in these polygons (sprite px). Hair above ROOT_Y is
# draped over the branch / on her head and stays in base.
ZONES = [
    # her right (viewer's left): long strands left of her face and body
    [(150, 118), (314, 118), (308, 200), (313, 270), (320, 330), (320, 382),
     (292, 430), (264, 470), (246, 520), (240, 650), (150, 650)],
    # her left (viewer's right): strands right of her head, behind her arm
    [(478, 100), (720, 100), (720, 650), (528, 650), (512, 540), (503, 420),
     (499, 300), (494, 214), (480, 180)],
]
ROOT_Y = 128
# Branch silhouettes behind the hair tips (filled in on base, so a sway
# shows bark, not a hole).
BEHIND = [
    [(196, 483), (236, 484), (252, 490), (252, 650), (196, 650)],
    [(525, 548), (576, 540), (612, 546), (660, 553), (720, 560), (720, 650), (525, 650)],
]
# Pale hair (where it fades from blonde to green) is the same lightness as
# her dress; there's no dress in the right zone, so only skin-coloured
# pixels count as "body" there.
FRONT_BAND = 16      # px of hair continued under the arm/dress/thigh


def classify(rgb, alpha):
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV_FULL).astype(np.int16)
    H, S, V = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    op = alpha > 24
    hair = op & (H >= 45) & (H <= 140) & (S >= 38) & (V >= 55)
    skin = op & (H <= 26) & (S < 80) & (V > 165)
    dress = op & (V > 200) & (S < 46) & (H >= 12) & (H <= 80)
    front = skin | dress
    brown = op & (H <= 32) & (S >= 70) & (V < 175)
    # Everything else (dark outlines, odd tones) goes to the nearest of the
    # three: lines inside the hair are hair, the arm's outline is arm, etc.
    cores = [hair, front, brown]
    d = np.stack([ndi.distance_transform_edt(~c) for c in cores])
    near = np.argmin(d, axis=0)
    cls = np.full(alpha.shape, -1, np.int8)
    for i, c in enumerate(cores):
        cls[c] = i
    amb = op & (cls < 0)
    cls[amb] = near[amb]
    # cls: -1 transparent, 0 hair, 1 front (body), 2 branch
    return cls, {"H": H, "S": S, "V": V, "hair": hair, "skin": skin, "dress": dress, "brown": brown}


def bleed(rgba):
    """Give fully transparent pixels the colour of the nearest visible one, so
    filtering/mipmaps never pull black into the edges (Godot's "fix alpha
    border" does this too; doing it here makes the PNGs safe either way)."""
    a = rgba[..., 3]
    vis = a > 0
    if vis.all() or not vis.any():
        return rgba
    _, (iy, ix) = ndi.distance_transform_edt(~vis, return_indices=True)
    out = rgba.copy()
    out[..., :3] = rgba[iy, ix, :3]
    out[..., 3] = a
    return out


def poly_mask(shape, polys):
    im = Image.new("L", (shape[1], shape[0]), 0)
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon(p, fill=255)
    return np.asarray(im) > 0


def main(src, dst, debug=None):
    os.makedirs(dst, exist_ok=True)
    im = np.asarray(Image.open(src).convert("RGBA"))
    rgb, alpha = im[..., :3].copy(), im[..., 3].copy()
    h, w = alpha.shape
    cls, c = classify(rgb, alpha)
    op = alpha > 24
    yy, xx = np.mgrid[0:h, 0:w]
    zl = poly_mask(alpha.shape, ZONES[:1])
    zr = poly_mask(alpha.shape, ZONES[1:])
    zone_any = zl | zr
    zone = zone_any & (yy >= ROOT_Y)
    hair_core = c["hair"] | (zr & (c["dress"] | c["skin"]) & (c["H"] > 26))
    # Her dress hem by her thigh (left zone, low down) is a pale yellow-green
    # a shade more saturated than the rest of the dress: still dress.
    hem = zl & (yy > 360) & (c["V"] >= 200) & (c["S"] < 54) & (c["H"] >= 30) & (c["H"] <= 85)
    hair_core &= ~hem
    front_core = (c["skin"] | c["dress"] | hem) & ~hair_core
    # Small bits of "body" colour inside the hair zones (highlights, pale
    # strand ends) aren't her arm: drop them, or they'd sit on the hair.
    # (Pieces are measured whole, so the dress hem — joined to the rest of
    # the dress outside the zone — counts as big.)
    lab, n = ndi.label(front_core, structure=np.ones((3, 3)))
    if n:
        sizes = ndi.sum(front_core, lab, range(1, n + 1))
        small = np.zeros(n + 1, bool)
        small[1:] = sizes < 300
        front_core &= ~(small[lab] & zone_any)
    # Her outline belongs to her: body = body colours plus ~2 px of line round
    # them (the line's soft edge is greenish where it meets her hair, so dark
    # pixels count even when they're hair-coloured).
    front = ndi.binary_dilation(front_core, iterations=2) & op & (~hair_core | (c["V"] < 165))
    # Bark = brown and the lines right next to real bark, never stray dark
    # pixels inside the hair.
    bl, bn = ndi.label(c["brown"])
    big = np.zeros(bn + 1, bool)
    if bn:
        big[1:] = ndi.sum(c["brown"], bl, range(1, bn + 1)) >= 500
    branch = (cls == 2) & ndi.binary_dilation(big[bl], iterations=4) & ~front
    hair_px = zone & op & ~front & ~branch
    # Hair strands over the branch: their dark outline is hair too (else it'd
    # stay behind on the bark as a ghost when the hair moves).
    behind_poly = poly_mask(alpha.shape, BEHIND)
    near_hair = ndi.binary_dilation(hair_px, iterations=3)
    edge = behind_poly & branch & near_hair & (c["V"] < 95)
    hair_px |= edge & zone
    branch &= ~hair_px
    # Specks: keep only sizeable connected hair pieces.
    lab, n = ndi.label(hair_px)
    sizes = ndi.sum(hair_px, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = sizes >= 60
    hair_px = keep[lab]
    cls = np.where(op, np.where(hair_px, 0, np.where(front, 1, 2)), -1).astype(np.int8)

    # ---- hair layer: hair pixels, continued a little under the body
    hair_rgb = rgb.copy()
    dist_h = ndi.distance_transform_edt(~hair_px)
    band = front & (dist_h <= FRONT_BAND) & poly_mask(alpha.shape, ZONES)
    # continue the hair from a px inside its edge (the edge still carries a
    # little of her outline)
    known = hair_px & ~ndi.binary_dilation(front, iterations=1)
    unknown = (~known).astype(np.uint8) * 255
    filled = cv2.inpaint(np.where(known[..., None], rgb, 0).astype(np.uint8), unknown, 7, cv2.INPAINT_TELEA)
    hair_a = np.where(hair_px, alpha, 0).astype(np.uint8)
    hair_a[band] = 255
    hair_rgb = np.where(band[..., None], filled, rgb)
    # A few rows of overlap above ROOT_Y (base keeps them too): the two layers
    # meet without a seam when she breathes.
    overlap = zone_any & op & ~front & ~branch & (yy >= ROOT_Y - 8) & (yy < ROOT_Y)
    overlap &= ndi.binary_dilation(hair_px, iterations=9)
    hair_a[overlap] = alpha[overlap]
    hair_rgb[overlap] = rgb[overlap]
    hair_rgb[hair_a == 0] = 0
    hair_img = np.dstack([hair_rgb, hair_a])

    # ---- base: hair taken out; where the branch is behind it, branch filled in
    behind_branch = hair_px & behind_poly
    # little gaps where a strand crossed the bark's edge
    behind_branch |= hair_px & ndi.binary_closing(branch | behind_branch, iterations=3)
    base_rgb = rgb.copy()
    base_a = alpha.copy()
    src_known = branch & ~ndi.binary_dilation(hair_px, iterations=1)
    inp_mask = (~src_known).astype(np.uint8) * 255
    br_fill = cv2.inpaint(np.where(src_known[..., None], rgb, 0).astype(np.uint8), inp_mask, 9, cv2.INPAINT_TELEA)
    base_rgb[hair_px] = 0
    base_a[hair_px] = 0
    base_rgb[behind_branch] = br_fill[behind_branch]
    base_a[behind_branch] = 255
    base_img = np.dstack([base_rgb, base_a])

    # ---- mask
    # R: rise when breathing in. Her body and head (incl. hair on her head),
    # fading from full above the shoulders to none where she sits; the branch
    # never moves.
    # Everything but the branch rises (empty space rising changes nothing),
    # so strand edges and gaps all move as one with no wobble.
    still = ndi.gaussian_filter(((alpha > 24) & (cls == 2)).astype(np.float32), 2.5)
    body_s = np.clip(1.0 - still * 1.2, 0, 1)
    prof = np.clip((yy - 30) / 80.0, 0, 1) * (1 - np.clip((yy - 230) / 230.0, 0, 1))
    prof = prof * prof * (3 - 2 * prof)
    lift = np.clip(body_s * prof, 0, 1)
    # G: head sway weight — her whole head moves as one (no shear across the
    # face), fading out down her neck and before the hair draped on the branch.
    def ss(a, b, v):
        t = np.clip((v - a) / (b - a), 0, 1)
        return t * t * (3 - 2 * t)
    head = ss(25, 55, yy) * (1 - ss(215, 285, yy)) * ss(285, 305, xx) * (1 - ss(478, 500, xx))
    head = ndi.gaussian_filter(head * body_s, 3.0)
    # B: in front of the hair (body pixels), crisp but anti-aliased
    front_m = ndi.gaussian_filter((front & (alpha > 24)).astype(np.float32), 0.7)
    # A: how freely the hair swings: less where the tips lie on the branch and
    # tuck under her hand (they'd drag on the bark there).
    rest = poly_mask(alpha.shape, BEHIND).astype(np.float32)
    rest = ndi.gaussian_filter(ndi.binary_dilation(rest > 0, iterations=10).astype(np.float32), 18.0)
    free = 1.0 - 0.6 * np.clip(rest * 1.3, 0, 1)
    mask = np.dstack([lift, head, front_m, free])
    mask_img = (np.clip(mask, 0, 1) * 255 + 0.5).astype(np.uint8)

    Image.fromarray(bleed(base_img), "RGBA").save(os.path.join(dst, "base.png"), optimize=True)
    Image.fromarray(bleed(hair_img), "RGBA").save(os.path.join(dst, "hair.png"), optimize=True)
    Image.fromarray(mask_img, "RGBA").save(os.path.join(dst, "mask.png"), optimize=True)

    if debug:
        os.makedirs(debug, exist_ok=True)
        vis = np.zeros((h, w, 3), np.uint8) + 30
        vis[cls == 0] = (60, 200, 90)
        vis[cls == 1] = (250, 180, 170)
        vis[cls == 2] = (140, 80, 40)
        vis[hair_px] = (120, 255, 140)
        vis[band] = (255, 60, 200)
        vis[behind_branch] = (255, 200, 0)
        Image.fromarray(vis).save(os.path.join(debug, "rig_classes.png"))
        dark = np.zeros((h, w, 4), np.uint8); dark[..., :3] = (40, 30, 60); dark[..., 3] = 255
        for name, img in (("base", base_img), ("hair", hair_img)):
            b = Image.fromarray(dark.copy(), "RGBA")
            b.alpha_composite(Image.fromarray(img, "RGBA"))
            b.convert("RGB").save(os.path.join(debug, "rig_" + name + ".png"))
        Image.fromarray(mask_img[..., :3]).save(os.path.join(debug, "rig_mask.png"))
    print(json.dumps({"hair_px": int(hair_px.sum()), "band": int(band.sum()), "behind_branch": int(behind_branch.sum())}))


if __name__ == "__main__":
    a = sys.argv[1:]
    dbg = None
    if "--debug" in a:
        i = a.index("--debug"); dbg = a[i + 1]; a = a[:i] + a[i + 2:]
    main(a[0], a[1], dbg)
