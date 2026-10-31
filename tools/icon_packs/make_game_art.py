"""Builds the puzzle's gem, special and border art from the free packs (round 35).

    python3 tools/icon_packs/make_game_art.py

Sources (tools/icon_packs/src/, see CREDITS there):
  MIX gems             rg_08 sg_19 mg_26 bg_16a pg_28 gg_27 dg_19 yg_27
  Ravenmore Icon Pack  FrameSquare, FrameRound

Writes:
  art/gems/<gem>.png           the six gems and the cursed shard (128 x 128)
  art/gems/rocket_h.png, rocket_v.png   a gold shard laid flat / upright with
                                        motion streaks
  art/gems/starburst.png       the Item Shop's Starburst Starter picture
  art/tiles/<girl>.png         a board cell: the square frame in her colour
  art/tiles/<girl>_slot.png    an item slot: the round frame in her colour
  art/frames/<girl>.png        the border around her board: the square frame
                               again, large, its face a little see-through
  art/ui/<name>.png            interface icons: white glyphs from Kenney's
                               Game Icons (tinted to each button's text
                               colour in the game), a painted gold star, a
                               painted heart (Ravenmore) and the hourglass
"""
import json
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
GEMS = os.path.join(ROOT, "art", "gems")
TILES = os.path.join(ROOT, "art", "tiles")
FRAMES = os.path.join(ROOT, "art", "frames")
SIZE = 128

# Each gem its own colour AND its own shape, so they can be told apart
# without colour too.
GEM_SOURCES = {
    "ember": "rg_08",      # red teardrop, like a flame
    "moonstone": "sg_19",  # silver round
    "petal": "mg_26",      # pink lozenge
    "pearl": "bg_16a",     # blue shield
    "rune": "pg_28",       # purple tablet
    "crystal": "gg_27",    # green shard
}


def load(name):
    return Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")


def fit(im, size=SIZE, pad=5):
    """Trims, then centres im in a size x size square with pad px around."""
    im = im.crop(im.getbbox())
    box = size - pad * 2
    im.thumbnail((box, box), Image.LANCZOS)
    out = Image.new("RGBA", (size, size))
    out.paste(im, ((size - im.width) // 2, (size - im.height) // 2), im)
    return out


def cursed():
    """A dark gem with glowing red cracks: plainly the one to avoid."""
    im = fit(load("dg_19")).copy()
    im = ImageOps.colorize(ImageOps.grayscale(im.convert("RGB")), black="#140b14", mid="#4a3346",
                           white="#b8a0b4").convert("RGBA")
    im.putalpha(fit(load("dg_19")).getchannel("A"))
    cracks = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(cracks)
    lines = [[(64, 16), (58, 40), (70, 58), (60, 80), (66, 108)],
             [(58, 40), (36, 52), (28, 70)],
             [(70, 58), (94, 64), (104, 84)],
             [(60, 80), (44, 92)]]
    for ln in lines:
        d.line(ln, fill=(255, 70, 90, 255), width=4, joint="curve")
    glow = cracks.filter(ImageFilter.GaussianBlur(4))
    out = Image.alpha_composite(im, glow)
    out = Image.alpha_composite(out, cracks)
    for ln in lines:
        ImageDraw.Draw(out).line(ln, fill=(255, 220, 220, 255), width=1)
    out.putalpha(ImageChops.multiply(out.getchannel("A"), im.getchannel("A")))
    return out


def rocket(vertical):
    """The gold shard laid along its row (or column) with speed streaks."""
    shard = load("yg_27")
    shard = shard.crop(shard.getbbox())
    # The source leans about 45 degrees; turn it flat (or upright).
    shard = shard.rotate(-45 if not vertical else 45, expand=True, resample=Image.BICUBIC)
    shard = shard.crop(shard.getbbox())
    shard.thumbnail((SIZE - 12, SIZE - 12), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE))
    streaks = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(streaks)
    for off, length in [(-26, 22), (0, 30), (26, 22)]:
        if vertical:
            d.line([(SIZE // 2 + off, 6), (SIZE // 2 + off, 6 + length)], fill=(255, 245, 190, 220), width=5)
            d.line([(SIZE // 2 + off, SIZE - 7), (SIZE // 2 + off, SIZE - 7 - length)], fill=(255, 245, 190, 220), width=5)
        else:
            d.line([(6, SIZE // 2 + off), (6 + length, SIZE // 2 + off)], fill=(255, 245, 190, 220), width=5)
            d.line([(SIZE - 7, SIZE // 2 + off), (SIZE - 7 - length, SIZE // 2 + off)], fill=(255, 245, 190, 220), width=5)
    out = Image.alpha_composite(out, streaks.filter(ImageFilter.GaussianBlur(2)))
    glow = Image.new("RGBA", (SIZE, SIZE))
    glow.paste(shard, ((SIZE - shard.width) // 2, (SIZE - shard.height) // 2), shard)
    halo = Image.new("RGBA", (SIZE, SIZE), (255, 220, 120, 0))
    halo.putalpha(glow.getchannel("A").filter(ImageFilter.GaussianBlur(7)))
    out = Image.alpha_composite(out, halo)
    return Image.alpha_composite(out, glow)


def tint_frame(src, colour, size, face_alpha=1.0):
    """The frame in one girl's colour: its dark face a deep shade of her
    colour, its rim a light one, keeping the painted shading."""
    im = load(src)
    im = im.crop(im.getbbox())
    alpha = im.getchannel("A")
    gray = ImageOps.autocontrast(ImageOps.grayscale(im.convert("RGB")))
    c = Image.new("RGB", (1, 1), colour).getpixel((0, 0))
    dark = tuple(int(v * 0.30) for v in c)
    light = tuple(int(v + (255 - v) * 0.72) for v in c)
    out = ImageOps.colorize(gray, black=dark, mid=c, white=light).convert("RGBA")
    if face_alpha < 1.0:
        # Only the dark face goes see-through; the bright rim stays solid.
        face = gray.point(lambda v: int(255 * face_alpha) if v < 110 else 255)
        alpha = ImageChops.multiply(alpha, face)
    out.putalpha(alpha)
    return out.resize((size, size), Image.LANCZOS)


# Kenney glyph -> the game's icon name (ArtAssets.ui_icon / UITheme.add_icon).
UI_GLYPHS = {
    "play": "right", "store": "shoppingBasket", "gallery": "menuGrid",
    "achievements": "trophy", "help": "question", "credits": "information",
    "quit": "exit", "settings": "gear", "menu": "home", "back": "return",
    "skip": "fastForward", "skip_all": "next", "auto": "right", "log": "menuList",
    "hide": "zoom",
}


def gold_star():
    """Kenney's star shape, painted gold: a gradient, a dark rim, a shine."""
    shape = Image.open(os.path.join(SRC, "kenney", "star.png")).convert("RGBA").getchannel("A")
    shape = shape.resize((SIZE - 16, SIZE - 16), Image.LANCZOS)
    mask = Image.new("L", (SIZE, SIZE))
    mask.paste(shape, (8, 8))
    grad = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(grad)
    for y in range(SIZE):
        t = y / SIZE
        d.line([(0, y), (SIZE, y)], fill=(255, int(236 - 70 * t), int(120 - 90 * t), 255))
    rim = Image.new("RGBA", (SIZE, SIZE), (150, 80, 10, 255))
    out = Image.new("RGBA", (SIZE, SIZE))
    out.paste(rim, (0, 0), mask.filter(ImageFilter.MaxFilter(7)))
    inner = mask.filter(ImageFilter.MinFilter(3))
    out.paste(grad, (0, 0), inner)
    shine = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(shine).ellipse([30, 22, 70, 52], fill=150)
    shine = ImageChops.multiply(shine.filter(ImageFilter.GaussianBlur(6)), inner)
    out.paste(Image.new("RGBA", (SIZE, SIZE), (255, 255, 240, 255)), (0, 0), shine)
    return out


def ui_icons():
    ui = os.path.join(ROOT, "art", "ui")
    os.makedirs(ui, exist_ok=True)
    for name, src in UI_GLYPHS.items():
        fit(Image.open(os.path.join(SRC, "kenney", src + ".png")).convert("RGBA"), 64, 4) \
            .save(os.path.join(ui, name + ".png"))
    gold_star().save(os.path.join(ui, "star.png"))
    fit(load("HeartFull"), SIZE, 4).save(os.path.join(ui, "heart.png"))
    hourglass = Image.open(os.path.join(ROOT, "art", "store", "moves.png")).convert("RGBA")
    fit(hourglass, SIZE, 4).save(os.path.join(ui, "hourglass.png"))


def main():
    os.makedirs(GEMS, exist_ok=True)
    os.makedirs(TILES, exist_ok=True)
    os.makedirs(FRAMES, exist_ok=True)
    for gem, src in GEM_SOURCES.items():
        fit(load(src)).save(os.path.join(GEMS, gem + ".png"))
    cursed().save(os.path.join(GEMS, "cursed.png"))
    rocket(False).save(os.path.join(GEMS, "rocket_h.png"))
    rocket(True).save(os.path.join(GEMS, "rocket_v.png"))
    star = Image.open(os.path.join(ROOT, "art", "store", "colorBomb.png")).convert("RGBA")
    fit(star, pad=4).save(os.path.join(GEMS, "starburst.png"))
    data = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
    chars = data if isinstance(data, list) else data["characters"]
    for ch in chars:
        tint_frame("FrameSquare", ch["c"], SIZE).save(os.path.join(TILES, ch["id"] + ".png"))
        tint_frame("FrameRound", ch["c"], SIZE).save(os.path.join(TILES, ch["id"] + "_slot.png"))
        tint_frame("FrameSquare", ch["c"], 192, face_alpha=0.7).save(os.path.join(FRAMES, ch["id"] + ".png"))
    ui_icons()
    print("gems, specials, interface icons and %d girls' tiles written" % len(chars))


if __name__ == "__main__":
    main()
