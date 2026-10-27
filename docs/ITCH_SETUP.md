# itch.io setup — Charm Combo

Charm Combo has four itch.io builds: Windows, Linux and Mac downloads, and a
version that plays right on the itch.io page. They come from the four
"(itch.io)" export presets and never touch Steam: achievements live in the
game's own Achievements screen instead.

## 1. Export the builds

In Godot: **Project > Export**, then **Export All...** and choose
**Release**. (That exports the Steam preset too, which is harmless.) The
builds land here:

| Preset | Output |
| --- | --- |
| Windows (itch.io) | `build/itch/windows/CharmCombo.exe` |
| Linux (itch.io) | `build/itch/linux/CharmCombo.x86_64` |
| macOS (itch.io) | `build/itch/mac/CharmCombo.zip` (the app, zipped) |
| Web (itch.io) | `build/itch/web/index.html` and its files |

Each one is a single file with the game packed inside, except the browser
version, which is a folder.

## 2. Make the page

On itch.io: **Dashboard > Create new project**.

- **Kind of project: HTML.** That puts the browser version at the top of the
  page, and the downloads still go underneath.
- **Embed options** (they appear once the browser build is uploaded):
  - Viewport: **1280 x 800** (the game's own size). If that's too big for
    small laptop screens, 960 x 600 also works; the game scales down.
  - **Fullscreen button**: on.
  - **Mobile friendly**: off. **Automatically start on page load**: off.
  - **SharedArrayBuffer support**: leave it off, the browser build doesn't
    need it.
- **Cover image**: 630 x 500 (see the "Launch" section of
  `docs/ART_LIST.md`). **Screenshots**: 3 to 5.
- Text for the description is in `docs/STORE_PAGE.md`.
- **The game is 18+**: mark the project as adult content on this page. See
  "Content questions" in `docs/STORE_PAGE.md`. **Adult content:** since July
  2025 itch.io has limited how adult NSFW pages are listed, paid ones most of
  all; if you add explicit night scenes or CGs, check its current rules before
  choosing a price.

## 3. Upload

### The easy way: butler (itch.io's upload tool)

1. Install butler: [itch.io/docs/butler](https://itch.io/docs/butler/), and
   run `butler login` once.
2. Open `itch/push_to_itch.bat` in a text editor and set `ITCH_GAME` to your
   itch name and the game's URL name. For `https://yourname.itch.io/charm-combo`
   that's `yourname/charm-combo`.
3. Double-click `push_to_itch.bat`. It uploads every build you've exported,
   using the version number from `project.godot`.
4. The first time only: on your game's **Edit** page, tick **"This file will
   be played in the browser"** next to the `html5` upload, and save.

Next time, just export and run `push_to_itch.bat` again. butler only sends
what changed, and players with the itch app get the update automatically.

### Or through the website

Upload one zip per build on the game's **Edit** page, ticking Windows, Linux
or macOS next to each, and **"This file will be played in the browser"** next
to the web one. This round's zips are ready in the delivered folder. After a
new export, double-click `itch/make_upload_zips.bat` to make fresh ones in
`build/itch/upload/`. (The Linux and Mac zips made on Windows lose the
"executable" permission those systems need, so butler is better for those
two.)

## 4. Good to know (maybe worth a line on the page)

- **Windows** may show "Windows protected your PC" the first time, because
  the game isn't code-signed. Players click **More info > Run anyway**.
- **Mac**: the app isn't notarized by Apple (that needs a paid Apple Developer
  account), so macOS blocks the first launch. On macOS 15 and later: try to
  open it once, then go to **System Settings > Privacy & Security** and click
  **Open Anyway**. On older versions: right-click the app and choose **Open**.
  Players who use the itch app skip this.
- **Linux**: a download from the website may need `chmod +x CharmCombo.x86_64`
  if the zip was made on Windows.
- **Browser version**: saves are kept in that browser, so another browser, a
  private window, or clearing site data starts fresh. There's no Quit button
  (a web page can't close itself), and Marina's swimming animation shows as
  her still picture (browsers can't load that animation's texture format).
- **Where saves live** on the downloads: Windows `%APPDATA%\CharmCombo`,
  Linux `~/.local/share/CharmCombo`, Mac
  `~/Library/Application Support/CharmCombo`.
- **Before you release**: set `ALLOW_TESTING_MODE := false` in
  `autoload/GameState.gd` and export again, so players don't see Testing Mode.

## Later: Steam keys for itch buyers

Once the game is on Steam, itch.io can hand each buyer a Steam key as well:
request keys in Steamworks, then add them in the game's distribution
settings on itch.io.
