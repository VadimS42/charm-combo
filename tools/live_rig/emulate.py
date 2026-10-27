"""Numpy stand-in for live_sprite.gdshader, to inspect a pose at full res."""
import sys, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi


def load(p):
    return np.asarray(Image.open(p).convert("RGBA")).astype(np.float32) / 255.0


def sample(img, x, y):
    # bilinear, clamp to edge
    h, w = img.shape[:2]
    return np.stack([ndi.map_coordinates(img[..., c], [y - 0.5, x - 0.5], order=1, mode="nearest") for c in range(img.shape[2])], axis=-1)


def render(d, lift=0.0, head=0.0, phase=0.0, sway=0.0, swish_ph=0.0, swish=0.0, blink=0, cfg=None):
    base, hair, mask = d["base"], d["hair"], d["mask"]
    H, W = base.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32) + 0.5
    m = mask
    pbx = xx - head * m[..., 1]
    pby = yy + lift * m[..., 0]
    b = sample(base, pbx, pby)
    if blink and "blink" in d:
        bx, by, bw, bh = cfg["blink_rect"]
        lx = (pbx - bx) / bw
        ly = (pby - by) / bh
        inside = (lx >= 0) & (ly >= 0) & (lx < 1) & (ly < 1)
        bt = d["blink"]
        ex = (np.clip(lx, 0, 0.999) + blink - 1) / 2.0 * bt.shape[1]
        ey = np.clip(ly, 0, 0.999) * bt.shape[0]
        e = sample(bt, ex, ey)
        a = e[..., 3:4] * inside[..., None]
        b[..., :3] = b[..., :3] * (1 - a) + e[..., :3] * a
    k = cfg.get("wave_k", 0.009)
    r = np.clip((yy - cfg["hair_root_y"]) / (cfg["hair_tip_y"] - cfg["hair_root_y"]), 0, 1)
    bend = r * r * (0.65 + 0.35 * (3 - 2 * r))
    w1 = np.sin(phase - k * yy + xx * 0.0035)
    w2 = np.sin(1.83 * phase - 1.7 * k * yy + 1.3)
    dx = (sway * (w1 + 0.28 * w2) + swish * np.sin(swish_ph - 1.6 * k * yy)) * bend * m[..., 3]
    t = np.clip((yy - 230) / 370, 0, 1)
    hl = lift * (1 - 0.5 * t * t * (3 - 2 * t))
    hr = sample(hair, xx - dx, yy + hl)
    front = sample(mask, pbx, pby)[..., 2]
    ha = hr[..., 3] * (1 - front)
    oa = ha + b[..., 3] * (1 - ha)
    oc = (hr[..., :3] * ha[..., None] + b[..., :3] * (b[..., 3] * (1 - ha))[..., None]) / np.maximum(oa, 1e-4)[..., None]
    return np.dstack([oc, oa])


def on_bg(rgba, col=(0.93, 0.85, 0.9)):
    bg = np.ones_like(rgba[..., :3]) * np.array(col)
    a = rgba[..., 3:4]
    return (np.clip(rgba[..., :3] * a + bg * (1 - a), 0, 1) * 255).astype(np.uint8)


if __name__ == "__main__":
    live = sys.argv[1]
    cfg = json.load(open(live + "/live.json"))
    d = {n: load(live + "/" + n + ".png") for n in ("base", "hair", "mask", "blink")}
    out = sys.argv[2]
    for name, kw in [("rest", {}), ("swayL", dict(phase=np.pi / 2 + 0.0, sway=-cfg["sway_px"] * 1.15)),
                     ("swayR", dict(phase=np.pi / 2, sway=cfg["sway_px"] * 1.15)),
                     ("inhale", dict(lift=cfg["breath_px"] + 4.0, head=1.0)), ("shake", dict(lift=1.0, head=3.2)), ("blink", dict(blink=2))]:
        Image.fromarray(on_bg(render(d, cfg=cfg, **kw))).save(out + "/emu_" + name + ".png")
