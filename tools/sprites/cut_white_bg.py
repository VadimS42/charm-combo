"""Cuts a character drawn on plain white out to a transparent PNG (round 38).

    python3 tools/sprites/cut_white_bg.py <in image> <out .png>

Only the white connected to the picture's edge goes, so her eyes, highlights
and the dagger's shine stay. The edge pixels get a soft alpha and the white
fringe taken out of their colour, so she has no halo on dark backgrounds.
The result is trimmed to her.
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage


def main():
    src, out = sys.argv[1], sys.argv[2]
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    near = rgb.min(axis=2) > 232
    labels, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    bg = np.isin(labels, edge[edge > 0])
    # Background showing through a loop (her tail): large, enclosed and
    # practically pure white. Small white bits (eyes, shine) stay.
    sizes = ndimage.sum(near, labels, index=np.arange(labels.max() + 1))
    means = ndimage.mean(rgb.min(axis=2), labels, index=np.arange(labels.max() + 1))
    holes = [i for i in range(1, labels.max() + 1) if sizes[i] > 2500 and means[i] > 248]
    bg |= np.isin(labels, holes)
    ring = ndimage.binary_dilation(bg, iterations=3) & ~bg
    # Over white: alpha is how far the darkest channel is from white.
    a_ring = np.clip((255.0 - rgb.min(axis=2)) / 255.0 * 1.6, 0.0, 1.0)
    alpha = np.where(bg, 0.0, np.where(ring, a_ring, 1.0))
    safe = np.maximum(alpha, 1e-3)[..., None]
    col = np.clip((rgb - (1.0 - alpha[..., None]) * 255.0) / safe, 0, 255)
    col = np.where(ring[..., None], col, rgb)
    rgba = np.dstack([col, alpha * 255.0]).astype(np.uint8)
    im = Image.fromarray(rgba, "RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    im.save(out)
    print(out, im.size)


if __name__ == "__main__":
    main()
