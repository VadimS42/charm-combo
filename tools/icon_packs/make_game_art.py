"""Builds the puzzle's gem, special and border art from the free packs (round 35).

    python3 tools/icon_packs/make_game_art.py

Sources (tools/icon_packs/src/, see CREDITS there):
  MIX gems             rg_08 sg_19 mg_26 bg_16a pg_28 gg_27 dg_19 yg_27
  Ravenmore Icon Pack  FrameSquare, FrameRound

Writes:
  art/gems/<gem>.png           the six gems and the cursed shard (128 x 128)
  art/gems/rocket_h.png, rocket_v.png   a gold shard laid flat / upright with
                                        motion streaks
  art/gems/starburst.png       a gold gem with a burst of light (also the
                               Starburst Starter's shop picture)
  art/store/<item>.png         the power-ups (round 36, replacing AI art):
                               Time Scroll, Hammer, Shuffle Wand, Starburst
                               Starter, Love Potion, Mending Potion
  art/tiles/<girl>.png         a board cell: the square frame in her colour
  art/tiles/<girl>_slot.png    an item slot: the round frame in her colour
  art/frames/<girl>.png        the border around her board: the square frame
                               again, large, its face a little see-through
  art/ui/<name>.png            interface icons: white glyphs from Kenney's
                               Game Icons (tinted to each button's text
                               colour in the game), a painted gold star, a
                               painted heart (Ravenmore) and an hourglass
                               (game-icons.net, Lorc, CC BY 3.0)
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
    # By the alpha channel: invisible pixels with a colour still count for
    # getbbox() on RGBA, which left some pictures tiny in their square.
    im = im.crop(im.getchannel("A").getbbox())
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
    # game-icons.net "hourglass" by Lorc (CC BY 3.0), black: made white
    # like the other glyphs.
    hg = load("hourglass_lorc")
    white = Image.new("RGBA", hg.size, (255, 255, 255, 255))
    white.putalpha(hg.getchannel("A"))
    fit(white, 64, 4).save(os.path.join(ui, "hourglass.png"))
    # Round 40: the last emoji. Painted pictures for light backgrounds.
    fit(load("Letter"), SIZE, 4).save(os.path.join(ui, "letter.png"))      # your replies
    fit(load("TomeRed"), SIZE, 4).save(os.path.join(ui, "book.png"))       # dialogue controls
    fit(load("X"), SIZE, 4).save(os.path.join(ui, "no.png"))               # "Dislikes"
    fit(load("Scroll"), SIZE, 4).save(os.path.join(ui, "scroll.png"))      # out of moves
    gems = [Image.open(os.path.join(GEMS, g + ".png")).convert("RGBA") for g in ("ember", "pearl", "crystal")]
    combo = Image.new("RGBA", (SIZE, SIZE))
    for g, (x, y) in zip(gems, [(-30, 18), (0, -20), (30, 18)]):
        g = g.resize((70, 70), Image.LANCZOS)
        combo.alpha_composite(g, (SIZE // 2 - 35 + x, SIZE // 2 - 35 + y))
    fit(combo, SIZE, 4).save(os.path.join(ui, "combo.png"))                 # combos
    painted_glyph("present", "#FF8FB8", "#D9346E", "#7A1238").save(os.path.join(ui, "gift.png"))
    # Each girl's gift, for the roster's gift button (game-icons.net, CC BY 3.0).
    gifts = os.path.join(ROOT, "art", "gifts")
    os.makedirs(gifts, exist_ok=True)
    for gift, (src, top, bottom, rim) in {
        "seaGlass": ("gem-pendant", "#B8F2E6", "#3FB7A8", "#145A52"),
        "pocketSundial": ("sundial", "#F5D58A", "#B07A2A", "#5A3A0E"),
    }.items():
        painted_glyph(src, top, bottom, rim).save(os.path.join(gifts, gift + ".png"))
    # These two read badly as filled silhouettes (their detail is cut-outs),
    # so they're drawn here.
    candle().save(os.path.join(gifts, "beeswaxCandle.png"))
    marble().save(os.path.join(gifts, "goldMarble.png"))


def _shade(size, top, bottom):
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    for x in range(size[0]):
        k = abs(x / max(1, size[0] - 1) - 0.35) / 0.65
        d.line([(x, 0), (x, size[1])], fill=tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)) + (255,))
    return g


def candle():
    """A tall beeswax candle, a drip down its side, lit."""
    out = Image.new("RGBA", (SIZE, SIZE))
    body = Image.new("L", (SIZE, SIZE))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle([44, 46, 84, 120], radius=6, fill=255)
    d.ellipse([40, 40, 88, 54], fill=255)
    d.rounded_rectangle([78, 50, 88, 82], radius=5, fill=255)  # drip
    wax = _shade((SIZE, SIZE), (255, 236, 170), (214, 150, 52))
    out.paste((110, 66, 14, 255), (0, 0), body.filter(ImageFilter.MaxFilter(5)))
    out.paste(wax, (0, 0), body)
    d2 = ImageDraw.Draw(out)
    d2.line([(64, 30), (64, 46)], fill=(60, 40, 30, 255), width=3)  # wick
    glow = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(glow).ellipse([38, 2, 90, 50], fill=150)
    out.paste((255, 200, 90, 255), (0, 0), glow.filter(ImageFilter.GaussianBlur(10)))
    flame = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(flame).polygon([(64, 6), (76, 28), (70, 38), (58, 38), (52, 28)], fill=255)
    out.paste((255, 150, 40, 255), (0, 0), flame.filter(ImageFilter.GaussianBlur(1)))
    core = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(core).ellipse([59, 22, 69, 37], fill=255)
    out.paste((255, 250, 210, 255), (0, 0), core.filter(ImageFilter.GaussianBlur(1)))
    return out


def marble():
    """A glass marble with a twist of gold through it."""
    out = Image.new("RGBA", (SIZE, SIZE))
    ball = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(ball).ellipse([14, 14, SIZE - 14, SIZE - 14], fill=255)
    glass = Image.new("RGBA", (SIZE, SIZE))
    gd = ImageDraw.Draw(glass)
    for r in range(50, 0, -1):
        k = r / 50
        gd.ellipse([64 - r - 8, 64 - r - 8, 64 + r + 8, 64 + r + 8],
                   fill=(int(150 + 70 * (1 - k)), int(200 + 40 * (1 - k)), int(225 + 25 * (1 - k)), 255))
    out.paste((40, 90, 110, 255), (0, 0), ball.filter(ImageFilter.MaxFilter(5)))
    out.paste(glass, (0, 0), ball)
    ribbon = Image.new("L", (SIZE, SIZE))
    rd = ImageDraw.Draw(ribbon)
    rd.arc([22, 30, 106, 98], 200, 340, fill=255, width=12)
    rd.arc([22, 30, 106, 98], 20, 160, fill=255, width=12)
    ribbon = ImageChops.multiply(ribbon, ball.filter(ImageFilter.MinFilter(9)))
    out.paste((230, 170, 40, 255), (0, 0), ribbon)
    out.paste((255, 225, 120, 255), (0, 0), ribbon.filter(ImageFilter.MinFilter(5)))
    shine = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(shine).ellipse([34, 26, 62, 48], fill=200)
    out.paste((255, 255, 255, 255), (0, 0), ImageChops.multiply(shine.filter(ImageFilter.GaussianBlur(5)), ball))
    return out


def painted_glyph(name, top, bottom, rim):
    """A black game-icons.net silhouette painted like the pack art: a
    top-to-bottom gradient, a dark rim and a soft shine."""
    shape = Image.open(os.path.join(SRC, "game-icons", name + ".png")).convert("RGBA").getchannel("A")
    shape = shape.crop(shape.getbbox()).resize((SIZE - 20, SIZE - 20), Image.LANCZOS)
    mask = Image.new("L", (SIZE, SIZE))
    mask.paste(shape, (10, 10))
    hexrgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
    t, b = hexrgb(top), hexrgb(bottom)
    grad = Image.new("RGBA", (SIZE, SIZE))
    d = ImageDraw.Draw(grad)
    for y in range(SIZE):
        k = y / SIZE
        d.line([(0, y), (SIZE, y)], fill=tuple(int(t[i] + (b[i] - t[i]) * k) for i in range(3)) + (255,))
    out = Image.new("RGBA", (SIZE, SIZE))
    out.paste(Image.new("RGBA", (SIZE, SIZE), hexrgb(rim) + (255,)), (0, 0), mask.filter(ImageFilter.MaxFilter(5)))
    out.paste(grad, (0, 0), mask)
    shine = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(shine).ellipse([24, 14, 74, 50], fill=110)
    shine = ImageChops.multiply(shine.filter(ImageFilter.GaussianBlur(8)), mask)
    out.paste(Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255)), (0, 0), shine)
    return out


def starburst():
    """A gold gem with a four-pointed burst of light behind it."""
    out = Image.new("RGBA", (SIZE, SIZE))
    rays = Image.new("L", (SIZE, SIZE))
    d = ImageDraw.Draw(rays)
    c = SIZE / 2
    for dx, dy in [(1, 0), (0, 1), (0.7, 0.7), (0.7, -0.7)]:
        long = 62 if dx == 0 or dy == 0 else 40
        px, py = -dy, dx
        d.polygon([(c + dx * long, c + dy * long), (c + px * 9, c + py * 9),
                   (c - dx * long, c - dy * long), (c - px * 9, c - py * 9)], fill=255)
    glow = Image.new("RGBA", (SIZE, SIZE), (255, 236, 150, 255))
    out.paste(glow, (0, 0), rays.filter(ImageFilter.GaussianBlur(2)))
    halo = Image.new("L", (SIZE, SIZE))
    ImageDraw.Draw(halo).ellipse([24, 24, SIZE - 24, SIZE - 24], fill=200)
    out.paste(Image.new("RGBA", (SIZE, SIZE), (255, 210, 90, 255)), (0, 0), halo.filter(ImageFilter.GaussianBlur(10)))
    gem = fit(load("yg_19"), SIZE, 20)
    return Image.alpha_composite(out, gem)


# The Item Shop's power-ups (round 36): id -> Ravenmore picture.
STORE = {"moves": "Scroll", "hammer": "HammerT2", "shuffle": "WandT2",
         "favorCharm": "PotionRed", "heartMender": "PotionGreen"}


def store_icons():
    store = os.path.join(ROOT, "art", "store")
    for item, src in STORE.items():
        fit(load(src), SIZE, 4).save(os.path.join(store, item + ".png"))
    starburst().save(os.path.join(store, "colorBomb.png"))


def main():
    os.makedirs(GEMS, exist_ok=True)
    os.makedirs(TILES, exist_ok=True)
    os.makedirs(FRAMES, exist_ok=True)
    for gem, src in GEM_SOURCES.items():
        fit(load(src)).save(os.path.join(GEMS, gem + ".png"))
    cursed().save(os.path.join(GEMS, "cursed.png"))
    rocket(False).save(os.path.join(GEMS, "rocket_h.png"))
    rocket(True).save(os.path.join(GEMS, "rocket_v.png"))
    starburst().save(os.path.join(GEMS, "starburst.png"))
    store_icons()
    data = json.load(open(os.path.join(ROOT, "data", "characters.json"), encoding="utf-8"))
    chars = data if isinstance(data, list) else data["characters"]
    for ch in chars:
        tint_frame("FrameSquare", ch["c"], SIZE).save(os.path.join(TILES, ch["id"] + ".png"))
        tint_frame("FrameRound", ch["c"], SIZE).save(os.path.join(TILES, ch["id"] + "_slot.png"))
        tint_frame("FrameSquare", ch["c"], 192, face_alpha=0.7).save(os.path.join(FRAMES, ch["id"] + ".png"))
    ui_icons()
    achievements()
    print("gems, specials, interface icons and %d girls' tiles written" % len(chars))



# ---------------------------------------------------------------- achievements
# Round 36: the gameplay achievements' badges, from the same packs (Hazel's
# story achievements keep her face, tools/achievement_icons). 256 x 256: the
# square frame in a colour of its own, the picture inside.

def _badge(colour, picture, extra=None):
    out = tint_frame("FrameSquare", colour, 256)
    pic = picture.crop(picture.getchannel("A").getbbox())
    scale = 176 / max(pic.size)
    pic = pic.resize((round(pic.width * scale), round(pic.height * scale)), Image.LANCZOS)
    shadow = Image.new("RGBA", out.size)
    shadow.paste(Image.new("RGBA", pic.size, (0, 0, 0, 120)), ((256 - pic.width) // 2 + 4, (256 - pic.height) // 2 + 6),
                 pic.getchannel("A"))
    out = Image.alpha_composite(out, shadow.filter(ImageFilter.GaussianBlur(5)))
    out.paste(pic, ((256 - pic.width) // 2, (256 - pic.height) // 2), pic)
    if extra:
        d = ImageDraw.Draw(out)
        d.ellipse([168, 168, 236, 236], fill=colour, outline=(255, 255, 255), width=4)
        d.text((202, 202), extra, fill=(255, 255, 255), anchor="mm", font=_font(30))
    return out


def _font(px):
    from PIL import ImageFont
    for path in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf",
                 "/Library/Fonts/Arial Bold.ttf"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, px)
    return ImageFont.load_default(px)


def _group(images, offsets, size=256, scale=0.55):
    canvas = Image.new("RGBA", (size, size))
    for im, (dx, dy) in zip(images, offsets):
        g = im.copy()
        g.thumbnail((int(size * scale), int(size * scale)), Image.LANCZOS)
        canvas.alpha_composite(g, (size // 2 - g.width // 2 + dx, size // 2 - g.height // 2 + dy))
    return canvas.crop(canvas.getchannel("A").getbbox())


def achievements():
    out = os.path.join(ROOT, "art", "achievements")
    gem = lambda n: Image.open(os.path.join(GEMS, n + ".png")).convert("RGBA")
    big = lambda n: fit(load(n), 256, 6)
    badges = {
        "combo_3": ("#3FA9C9", _group([gem("ember"), gem("pearl"), gem("crystal")],
                                      [(-50, 30), (0, -30), (50, 30)]), "x3"),
        "combo_5": ("#2F7FB0", _group([gem("petal"), gem("rune"), gem("ember"), gem("pearl"), gem("crystal")],
                                      [(-72, 30), (-38, -20), (0, -45), (38, -20), (72, 30)], scale=0.42), "x5"),
        "make_starburst": ("#D9A21E", starburst(), None),
        "mega_blast": ("#E0602E", _group([starburst(), rocket(False), rocket(True)], [(0, 0), (0, 0), (0, 0)], scale=0.8), None),
        "charm_burst": ("#E0457B", big("HeartFull"), None),
        "moves_left_5": ("#6F8FD8", big("Scroll"), "+5"),
        "shard_smash": ("#5B4A78", _group([cursed(), big("HammerT2")], [(-28, 30), (30, -24)], scale=0.6), None),
        "first_purchase": ("#B07A3A", _group([big("Backpack"), big("Coin")], [(-14, -6), (52, 52)], scale=0.6), None),
    }
    for name, (colour, pic, extra) in badges.items():
        _badge(colour, pic, extra).save(os.path.join(out, name + ".png"))


if __name__ == "__main__":
    main()
