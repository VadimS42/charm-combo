"""Hazel's achievement icons: her face, zoomed in, with the expression that
fits each achievement, in a coloured frame (plus a small badge where it
helps tell them apart). Writes art/achievements/<id>.png at 256x256; then
tools/make_steam_achievement_icons.gd makes the Steam pairs from those.

Usage (from the project folder): python3 tools/achievement_icons/make_hazel_icons.py
Needs Pillow. The badge font is DejaVu Sans Bold (any bold .ttf works: FONT).
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
ART = os.path.join(ROOT, "art", "characters", "dryad")
OUT = os.path.join(ROOT, "art", "achievements")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
SIZE = 256
FACE = (195, 215, 645, 665)  # her face in the 803x1000 expression art

# id: (expression, frame colour, badge text or "")
ICONS = {
    "hazel_meet":     ("angry",     "#5E7F3A", ""),
    "hazel_ch1":      ("teasing",   "#7FA35A", "I"),
    "hazel_ch2":      ("shy",       "#C0573E", "II"),
    "hazel_ch3":      ("sad",       "#4C6A86", "III"),
    "ending_hazel":   ("happy",     "#C9A23C", ""),
    "hazel_gift":     ("surprised", "#B58A3A", ""),
    "hazel_sweet":    ("shy",       "#E07A9A", ""),
    "hazel_tease":    ("angry",     "#8E3B5A", ""),
    "combo_3":        ("happy",     "#5FA88F", "x3"),
    "combo_5":        ("surprised", "#3F8E9E", "x5"),
    "make_starburst": ("surprised", "#D9A93A", "✦"),
    "mega_blast":     ("surprised", "#D9653A", "✸"),
    "charm_burst":    ("shy",       "#E0577F", "♥"),
    "moves_left_5":   ("teasing",   "#6E8FC9", "+5"),
    "shard_smash":    ("angry",     "#5B4A7A", "✖"),
    "first_purchase": ("happy",     "#9A6FC0", "★"),
}


def hexcol(h, a=255):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def icon(expr, colour, badge):
    c = hexcol(colour)
    img = Image.new("RGBA", (SIZE, SIZE), c)
    face = Image.open(os.path.join(ART, expr + ".png")).convert("RGBA").crop(FACE).resize((SIZE, SIZE), Image.LANCZOS)
    img.alpha_composite(face)
    # a soft wash of the frame colour around the edges
    edge = Image.new("L", (SIZE, SIZE), 255)
    ImageDraw.Draw(edge).ellipse((18, 18, SIZE - 18, SIZE - 18), fill=0)
    edge = edge.filter(ImageFilter.GaussianBlur(26)).point(lambda v: int(v * 0.55))
    img.paste(Image.new("RGBA", (SIZE, SIZE), c), (0, 0), edge)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, SIZE - 1, SIZE - 1), outline=c, width=10)
    d.rectangle((10, 10, SIZE - 11, SIZE - 11), outline=(255, 255, 255, 150), width=2)
    if badge:
        r = 34
        cx, cy = SIZE - 20 - r, SIZE - 20 - r
        d.ellipse((cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3), fill=(255, 255, 255, 235))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)
        size = 34 if len(badge) <= 2 else 26
        font = ImageFont.truetype(FONT, size)
        d.text((cx, cy + 1), badge, font=font, fill="white", anchor="mm")
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (expr, colour, badge) in ICONS.items():
        icon(expr, colour, badge).save(os.path.join(OUT, name + ".png"))
    print("wrote %d icons to art/achievements/" % len(ICONS))


if __name__ == "__main__":
    main()
