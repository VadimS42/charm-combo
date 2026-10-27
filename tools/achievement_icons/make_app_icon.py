"""The game's app icon (round 28): Hazel's face, zoomed in, biting her lip
(her "teasing" expression), on a rounded square in her colours.

Writes icon.png (1024 x 1024, the window/taskbar icon, project.godot
config/icon) and icon.ico (16-256 px, written into the Windows .exe by the
export presets). Usage: python3 tools/achievement_icons/make_app_icon.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC = os.path.join(ROOT, "art", "characters", "dryad", "teasing.png")
FACE = (225, 255, 615, 645)  # eyes to chin, in the 803x1000 expression art
N = 1024
R = 200  # corner radius


def main():
    face = Image.open(SRC).convert("RGBA").crop(FACE).resize((N, N), Image.LANCZOS)
    bg = Image.new("RGBA", (N, N))
    top, bottom = (0x8D, 0xB4, 0x6E), (0xF2, 0xB8, 0xC6)
    d = ImageDraw.Draw(bg)
    for y in range(N):
        t = y / (N - 1)
        d.line([(0, y), (N, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    bg.alpha_composite(face)
    # soft edge glow in her green, then a rounded-square mask with a border
    mask = Image.new("L", (N, N), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, N - 1, N - 1), R, fill=255)
    edge = Image.new("L", (N, N), 0)
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, N - 1, N - 1), R, outline=255, width=60)
    edge = edge.filter(ImageFilter.GaussianBlur(30))
    bg.paste(Image.new("RGBA", (N, N), (0x5E, 0x9E, 0x45, 255)), (0, 0), edge.point(lambda v: int(v * 0.55)))
    ImageDraw.Draw(bg).rounded_rectangle((8, 8, N - 9, N - 9), R - 8, outline=(0x6E, 0x8F, 0x4A, 255), width=16)
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    out.save(os.path.join(ROOT, "icon.png"))
    out.save(os.path.join(ROOT, "icon.ico"), sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print("wrote icon.png and icon.ico")


if __name__ == "__main__":
    main()
