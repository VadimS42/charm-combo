# Charm Combo — handover

Updated November 2026, after round 45. This document is for whoever picks the
project up next: what the game is, how to run, build and test it, how the code
and data fit together, and what is still open. `README.md` has the round-by-round
history; this is the short version.

---

## 1. What it is

An 18+ match-3 dating game in **Godot 4.3** (GDScript, standard build, not .NET).

**The cast.** Four girls, each with her own short story, told in visual-novel
dialogue between match-3 chapters:

| Girl | Story id | Who she is |
|---|---|---|
| Amara Duskrose | `succubus` | A succubus, summoned by mistake |
| Marina Waverly | `mermaid` | A mermaid of Saltwick Cove |
| Opal | `slime` | A slime, formerly of a jar |
| Hazel Mossgrove | `dryad` | A dryad of the old hazel |

**A girl's story** runs as follows:
1. Her intro.
2. Four chapters, each followed by a reply that changes her next chapter.
3. A night scene with three full-screen pictures.
4. An epilogue.

**The puzzle.**
- An 8×8 board with six gems and a cursed shard. Matching 4 makes a Rocket; matching 5, or an L or T shape, makes a Starburst.
- Every match fills a Charm ring.
- **Her chapter structure (round 44):**
  - Chapter 1 is a plain score target.
  - Chapter 2 adds her own board piece.
  - Chapter 3 is her goal only.
  - Chapter 4 is her goal plus a score target.
- **Her pieces:**
  - Amara: ink seals on gems.
  - Marina: the tide, with comb pieces to bring up.
  - Opal: moss hiding her lost things.
  - Hazel: seeds that grow into blossoms.
- From chapter 2, a full Charm ring gives one use of her power.
- Her favourite gem scores ×2 and the one she dislikes ×0.5.
- **Difficulty:** Easy, the default, is the puzzle above. Hard adds "date events" every few moves (round 41).

**Around the story.**
- **Stars:** clearing a chapter earns stars, which buy power-ups in the Item Shop. Losing still pays a few. Cleared chapters can be replayed from her card for half pay.
- **Gifts:** each girl has a gift that permanently boosts her favourite gem.
- **Also in the game:** Gallery, Achievements (Steam-ready), Settings, Credits, Russian and Simplified Chinese text, voice acting, and keyboard / controller / Steam Deck play.

---

## 2. Running, building, testing

### Run it

1. Install Godot 4.3 (standard): https://godotengine.org/download/archive/4.3-stable/
2. Project Manager → **Import** → pick `project.godot`. The first import takes about a minute.
3. Press **F5**.

Settings → **Testing Mode** clears a chapter on any move. Use it to go through stories quickly.

### Build it

Export presets are in `export_presets.cfg`:

| Preset | Notes |
|---|---|
| Windows (Steam) | Needs GodotSteam and `Platform.STEAM_APP_ID` |
| Windows (itch.io) | The one used for test builds |
| Linux (itch.io) | |
| macOS (itch.io) | |
| Web (itch.io) | |
| Windows (Demo) | Hazel only |
| Windows (Epic) | Safe for work, no Steam (round 46): `docs/EPIC_SETUP.md` |
| Android | Safe for work (round 46): `docs/ANDROID_SETUP.md` |

The Epic and Android builds play the safe-for-work version. Run
`python3 tools/make_sfw_data.py` before exporting them (`docs/SFW_CONTENT.md`).

To build, install Godot's export templates once (Editor → Manage Export Templates), then use either:
- **The editor:** Project → Export → pick a preset → Export Project.
- **The command line:**
  ```
  godot --headless --path . --export-release "Windows (itch.io)" build/itch/windows/CharmCombo.exe
  ```

Every build is one `.exe` with the game embedded. `docs/STEAM_SETUP.md` and `docs/ITCH_SETUP.md` cover the store side.

### Test it

All tests are headless; run them from the project folder. They write to the user's save, so point `HOME` / `XDG_DATA_HOME` / `APPDATA` at an empty folder first.

| Command | What it checks |
|---|---|
| `godot --headless --path . -s tools/smoke_test.gd` | Every girl's story from intro to epilogue, night replays from the Gallery, "continue the story after 3 losses", chapter replay |
| `godot --headless --path . -s tools/mechanics_test.gd` | Every girl's four chapters on the real puzzle screen: real swaps, Hammer, Shuffle, her power, the hint |
| `godot --headless --path . -s tools/pad_test.gd` | Every screen walked with the D-pad: lists any button you can't reach, any screen with no starting focus, any focus that lands on something hidden. Run it with `SteamDeck=1` too |
| `godot --headless --path . -s tools/balance_bot.gd -- mode=girls girl=all runs=300` | Bot win % per chapter |
| `godot --headless --path . -s tools/balance_bot.gd -- mode=girldist ...` | Score / moves-needed spread, for tuning |
| `godot --headless --path . -s tools/balance_bot.gd -- mode=girlfuzz fuzz=10000` | Starting-board fuzz |

When run headless, the console shows "Identifier not found: GameState / SFX" compile errors at startup. They're harmless: scripts are compiled before the autoloads exist, then compiled again. Real errors show up after the "Charm Combo 1.0.0" line.

---

## 3. How the code is laid out

```
project.godot          autoloads, window 1280×800 (= Steam Deck)
scenes/Main.tscn       the one scene; Main.gd builds every screen in code
autoload/
  GameState.gd         save (user://save.json + backup), settings, progress, items, stars
  Nav.gd               keyboard/controller "nav mode", input actions, button names, Steam Deck
  Platform.gd          Steam (GodotSteam if present), demo/trailer flags, store URL
  Voice.gd, Music.gd, SFX.gd, Achievements.gd
scripts/
  Main.gd              screen switching, floating stars/Settings, hint pill, modals, toasts
  StoryFlow.gd         story order: intro → chapters → night → epilogue; stars paid
  CharacterData.gd     loads data/characters.json; gem names/colours/weights
  MatchEngine.gd       pure match-3 rules (matches, specials, gravity)
  PuzzleRules.gd       round 44: her piece, goal, power, scoring; shared by game and bot
  ArtAssets.gd         every art lookup (missing files fall back to placeholders)
  UITheme.gd           colours, fonts, styled widgets, translation helper t()
  HowToPlay.gd         rules page + first-time tips
  LiveSprite.gd        breathing/blinking sprites (art/characters/<id>/live)
  screens/             one file per screen: Puzzle, VN (dialogue), Roster, Store,
                       Settings, Gallery, Achievements, Credits, endings, age gate
backup/puzzle_classic/ the puzzle as it was before round 41 (not loaded)
```

Main points:
- **UI in code.** Everything is built in code; there are almost no `.tscn` files to edit. Each screen is a `setup()`/builder that adds Controls under `Main.screen_host`.
- **Puzzle state.** `PuzzleScreen.gd` owns a chapter's state but delegates the rules to `PuzzleRules` + `MatchEngine`. It animates between their steps (clear → score → collapse → render). Every `await` is followed by a `_torn_down` check, because the player can leave mid-animation.
- **Controller support.** Every screen calls `main.nav_setup(first_focus, back_action, shortcut_actions, hints)`. Nav mode starts on the first key or pad press and ends when the mouse moves. On a Steam Deck (env `SteamDeck=1`) it starts in pad mode and the first launch is fullscreen.

---

## 4. Data and content pipelines

### Story and numbers: `data/characters.json`

One entry per girl, holding:
- Her lines (each spoken line has an `id`, which is its voice clip name), expressions (`e`) and delivery notes (`d`).
- Her favourite and least-liked gems, her gift, her quips, her Hard-mode `dateEvents`, and her `power`.
- Per chapter: `target`, `moves`, `mech`, `pieces` and `goal`.

`docs/EDITING_DIALOGUE.md` explains editing. A `characters.json` placed next to the exported game overrides the built-in one, so a writer can test changes without the editor.

### Voice: `audio/voice/<id>/<line id>.ogg`

| Tool | What it does |
|---|---|
| `tools/voice_script/make_voice_script.py` + `make_voice_docx.js` + `make_easy_copy.py` | The actor scripts in `docs/voice/` (xlsx, docx, `lines_<Name>.txt`) |
| `tools/voice_import/import_voice.py` | Recordings as one `.wav` per line → trimmed, -18 LUFS `.ogg`. Manual cuts go in `takes.json` |
| `tools/voice_import/cut_takes.py` | Long recordings with many lines → clips, from hand-picked times (Opal: `opal_cuts.json`) |
| `tools/voice_import/check_clips.py` | Whisper (sherpa-onnx, small.en) listens to every clip and lists any that don't match their text |

### Translations: `translations/ru.po`, `zh_CN.po`

1. `tools/i18n/make_txt.py` writes `translations/txt/en/*.txt` (one piece per `@@ key`) and `keys.json`.
2. Translators fill copies of those files.
3. `tools/i18n/import_txt.py <locale> <files>` writes them into the `.po`.

`docs/TRANSLATING.md` covers this. Text built at runtime goes through `UITheme.t()`; add new pieces like that to `UI_EXTRA` in `make_txt.py`.

### Art

`docs/ART_LIST.md` lists every image the game looks for, with its status.

`tools/icon_packs/make_game_art.py` builds all the interface art from the free packs:

| Pack | Used for |
|---|---|
| MIX gems | The gems |
| Ravenmore Icon Pack 2023 | Frames, items, potions |
| Kenney Game Icons | Interface glyphs |
| game-icons.net (Lorc, Delapouite) | Gifts, pieces, powers |
| Celyanae Match-3 | Lock, moss floor |

Sources and credits are in `tools/icon_packs/src/`. Run the script again after changing anything there.

The sprite tools:
- `tools/sprites/cut_white_bg.py` removes a white background.
- `tools/live_rig/` makes the breathing/blinking rigs: `blink_simple.py` for a blink only, as Amara has.

---

## 5. What's done (state at round 45)

**Story and text**
- All four stories are complete and playable start to finish, in English, Russian and Chinese.

**Voice**

| Girl | Clips | Status |
|---|---|---|
| Marina | 78 | Complete |
| Hazel | 72 | Complete |
| Opal | 70 | Complete |
| Amara | 72 of 80 | Missing `amara_end_06`, `amara_end_07` and her six sounds (laughs and unhappy). Missing clips just stay silent. |

**Art in the game**

| Girl | Art |
|---|---|
| Marina | Expressions, swim loop, ending, background (the beach castle, round 45) |
| Hazel | Expressions, live sprite |
| Amara | Main sprite with a blink |

The gems, items, frames, pieces, powers, achievement badges and app icon are in too.

**Puzzle balance** (casual bot, no items, round 44)
- Chapters 1–2 win 73–87%; chapters 3–4 win 57–76%.
- Later chapters are meant to want power-ups.

**Controller / Steam Deck (round 45)**
- Every screen is fully reachable with the D-pad (`pad_test.gd`).
- Button hints show in a pill at the top centre while you use a pad.
- In a chapter, each item and her power button shows its own button name.
- On the Deck it starts in pad mode, fullscreen, with Deck button names (L1/R1).
- The full control list is in the header of `autoload/Nav.gd`.

---

## 6. Open items

**Art still to make or commission** (the details are in `docs/ART_LIST.md`)
- **Opal:** no art at all. She shows a round "O" placeholder, which needs her sprite and expressions.
- **Amara:** expressions, if wanted beyond her main sprite.
- **Backgrounds:** Amara's library, Opal's woods and Hazel's grove. For now each shows a drawn backdrop in her colour.
- **Story pictures:** the night-scene pictures (three per girl, none yet) and the ending pictures (only Marina's exists). Placeholder cards show until they're added.

**Voice**
- Amara's `end_06`, `end_07` and her six sounds.

**Credits to fill in** (in `data/credits.txt`)
- Your name / studio and the artists' names.
- The composer of "morning_2d".
- The author and licence of "MIX gems".

**Safe-for-work version (Epic, Android)**
- Write the safe-for-work night scenes / epilogues / lines and add the `_sfw` pictures: `docs/SFW_CONTENT.md`.
- Mobile interface (round 47): the menus, chapters, dialogue and Settings are redesigned for phones, portrait and landscape. The ending screens, age gate and language picker are still the desktop ones, made to fit (`docs/ANDROID_SETUP.md`, "Not done yet").
- Main focus stays the Windows / Steam build; every mobile change is behind `Platform.mobile`.

**Release**
- **Steam:** set `Platform.STEAM_APP_ID` (now 0) and the store URL, add GodotSteam for the Steam build, and upload the achievement icons. `docs/STEAM_SETUP.md` has the steps; the store page text is in `docs/STORE_PAGE.md`.
- **Night scenes:** each girl's night scene still has a placeholder slot line where you put your own scene text. Search `characters.json` for `"k": "slot"`.

**Code notes**
- The older balance-bot modes (`plain`, `items`, `campaign`, `dist`) still score the round-33 way. The `girls*` modes are the ones that match the game.
- The `backup/puzzle_classic/` folder isn't loaded (it has a `.gdignore`); it's there for reference only.

---

## 7. Where the work lives

- **Repository:** https://github.com/VadimS42/charm-combo
- **Working branch:** `claude/intelligent-cannon-dj1vi1`, with pull request #1 into `main`. Merge it to make `main` current.
- **Builds:** `build/` is not committed; export into it.
