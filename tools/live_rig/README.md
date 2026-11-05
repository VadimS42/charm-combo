# Live sprite tools (round 20)

How Hazel's chapter sprite was made to breathe, sway and blink. Needs Python 3
with numpy, scipy, opencv-python and pillow. None of this ships with the game
(`tools/` is left out of every export).

1. `art_prep_remove_white_bg.py <src dir> <out dir>`: her art drawn on a white
   page (the seven expressions plus `main.png`) to transparent PNGs, 1000 px
   tall. Gives `art/characters/<id>/main.png`.
2. `rig_live.py <main.png> art/characters/<id>/live [--debug <dir>]`: cuts the
   main sprite into `base.png` (body and tree, hanging hair removed), `hair.png`
   (the hanging hair) and `mask.png` (breathing / head / "in front of the hair"
   / how freely the hair swings). The polygons at the top of the file (`ZONES`,
   `BEHIND`, `ROOT_Y`) are Hazel's; another girl needs her own. `--debug`
   writes a colour map of what went where.
3. `blink.py <high-res page png> art/characters/<id>/live`: paints her eyes
   half-shut and shut from the high-res art, scaled to the sprite: `blink.png`
   and `blink.json` (copy its `blink_rect` into `live.json`). `EYES` at the top
   holds each eye's outline and closed-lid line, in page pixels.
4. `live.json` beside them: blink rect, hair root/tip heights, and the motion
   settings LiveSprite.gd reads (breath, sway, head drift, "ambient": "leaves").
   `"motion": false` keeps only the blinking (Hazel uses this), and
   `"ambient": "none"` turns the falling leaves off.
5. `emulate.py art/characters/<id>/live <out dir>`: renders a few poses (rest,
   hair swung both ways, a deep breath, a head shake, eyes shut) at full size
   to check for seams before opening Godot.

When Godot imports the new PNGs, give base, hair and blink mipmaps (their
`.import` files in this repo already do).
