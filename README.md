# Charm Combo — Godot port

This is the start of the Steam-bound rebuild of Charm Combo in Godot 4,
carried over from the HTML/JS prototype. It's a straight structural port:
same match-3 rules, same story-flow architecture — just running on a real
engine instead of a browser tab, so it can actually be built and shipped to
Steam.

The whole game is set in **Millbrook**, an original fantasy town where
fantastical folk live openly among everyone else. It's an **18+** romance
(round 21): a succubus you summon by accident in the library, a mermaid you
"rescue" from her own cove, a slime hiding in a jar you open, and a dryad whose
tree you were hired to cut down. See `data/characters.json` for their full
4-chapter arcs, and **`docs/EDITING_DIALOGUE.md`** to change any line yourself. **`docs/ART_LIST.md`**
is the complete list of art the game still needs — every file path, size and
scene brief (round 15); see "Art asset checklist" below for the short version.
Releasing: **`docs/STEAM_SETUP.md`** (Steam, step by step), **`docs/ITCH_SETUP.md`**
(itch.io) and `docs/STORE_PAGE.md` (starter text for both store pages).

## ✅ Status: round-33 — balance: easy start, power-ups for the second half

Asked for: simulate the puzzles; the first chapters easy, the later ones
needing power-ups, with replays of the early chapters as the way to earn them.

- **`tools/balance_bot.gd` rewritten.** Two bots ("careful" always takes the
  best swap; "casual" only 55% of the time, nearer a real player), every
  power-up applied the way `PuzzleScreen` applies it, and modes `plain`,
  `items`, `dist` (score spread) and `campaign` (a player going through a
  story from 0 stars, buying power-ups and replaying chapter 1 when short).
  `targets=` / `moves=` try numbers without editing the data.
- **Targets** (all four girls): 700 / 1030 / 1250 / 1350 → **900 / 1200 /
  1700 / 2000** (moves unchanged, 15 / 15 / 16 / 18). The old ones were cleared
  by the casual bot about 65% of the time even in chapter 4 with nothing.
- **Shop prices** follow what each item is worth in the simulation: +3 Moves
  12 → 15, Hammer 18 → 12, Shuffle 15 → 8, Starburst Starter 25 → 15, Favor
  Charm 18 → 22, Heart Mender 20 (same).
- **Replay a chapter** (her roster card, once she has a cleared chapter): plays
  it again with no story and no reply bonus, her progress stays put, and a
  clear pays half the first clear: 8 / 10 / 13 / 15 stars
  (`StoryFlow.replay_stars`). "Play it again", "Item Shop" or "Back to the roster".
- **Losing** now pays 1 star per 200 points (was 100), at least 3: about 7 for
  a lost chapter 3, so replaying chapter 1 (8, nearly sure) is the better way
  to save up. Shop and How to Play texts say so; Russian and Chinese added.
- Gift names on roster cards are translated now (they stayed English).

Casual bot, Hazel, reply bonus at random (200 runs each):

| Power-ups | Stars | Ch1 | Ch2 | Ch3 | Ch4 |
|---|---|---|---|---|---|
| none | 0 | 100% | 81% | 28% | 8% |
| +3 Moves | 15 | 100% | 96% | 55% | 23% |
| Favor Charm | 22 | 100% | 95% | 60% | 43% |
| Heart Mender | 20 | 100% | 94% | 56% | 33% |
| Favor + Mender | 42 | 100% | 99% | 87% | 78% |
| Favor + Mender + Moves | 57 | 100% | 100% | 98% | 91% |

Campaign (200 casual players, 0 stars, one girl): chapter 1 cleared first try
98%, chapter 2 77%; chapters 3 and 4 take about 2 power-ups and 2 replays of
chapter 1 each, and 6% still lean on "Continue the story" in chapter 4.
Meeting the other girls (their chapters 1 and 2 pay 35 stars each) also funds it.

## ✅ Status: round-32 — expressions match the lines

- Every line's `"e"` checked against what Hazel's and Marina's pictures
  actually show. Hazel's `teasing` is a sultry lip-bite, so it now marks only
  flirting: 12 of her lines moved (dry jokes such as the beehive/axe line and
  "a lovely trench" to `neutral`, jealousy to `angry`, mischief to `happy`,
  nervous or tender lines to `shy`). Marina: 5 lines (a defensive line to
  `shy`, a quiet tearful moment off her big grin, narration off the wink).
- `docs/EDITING_DIALOGUE.md` has a table of what each expression looks like
  for both girls. Voice script regenerated (it lists the portraits).

## ✅ Status: round-31 — Russian and Chinese are in; Millbrook; click finishes text

- **Translations:** all 743 pieces in Russian (`translations/ru.po`) and
  Simplified Chinese (`translations/zh_CN.po`), translated in a separate chat
  from the `.txt` files and imported with `tools/i18n/import_txt.py`. Checked on
  screen: picker, menu, roster, dialogue, replies, chapter, Settings.
- Text the game changes before showing (capitalised roles, quotes stripped
  off taglines, her first name in the speech box) is now translated first
  (`UITheme.unquote()`, `UITheme.first_name()`); "MOVES" and "TIP" added.
- **The town is Millbrook** (was Duskhaven) in the story, menus, docs, store
  page text and both translations (Миллбрук, 米尔布鲁克). No recorded voice line
  named it.
- **Dialogue:** a click while a line is typing now shows it whole (the typing
  tween used to keep running and undo it); the next click moves on.

## ✅ Status: round-30 — Chinese and Russian (text ready for translation)

- **Language picker** on first launch (before the age notice: English, 简体中文,
  Русский), and a Language row at the top of Settings. Voices stay English.
- **Plumbing:** Godot's translation files `translations/ru.po` and
  `translations/zh_CN.po` (empty for now); labels and buttons translate by their
  English text, text built in code goes through `UITheme.t()`.
- **Text for translators:** `translations/txt/en/` (each girl's dialogue, about
  1,850 words apiece, and the interface, about 1,400), made by
  `tools/i18n/make_txt.py`; `tools/i18n/import_txt.py` reads the translated
  files back. See `docs/TRANSLATING.md`.
- **Chinese font:** `assets/fonts/CharmComboCJK.otf` (Noto Sans CJK SC, GB2312
  subset, 3 MB, OFL). Tested with the system's Chinese fonts removed.

## ✅ Status: round-29 — three pictures per night scene; .exe icon

- **Night scenes** switch between three full-screen pictures in
  `art/characters/<id>/cg/`: `night_lead.png` (from the start), `night_act.png`
  (from the line with `"cg": "night_act"`: put it on the first line of your
  own part when you replace the slot; the slot carries it as a reminder) and
  `night_after.png` (from the "Later." / "Afterwards" line, which carries
  `"cg": "night_after"`). Any line in a CG scene can carry `"cg"`; the picture
  crossfades in 0.4 s (instant with Reduce Motion) and stays until another
  line changes it. Missing 2nd/3rd picture: the one showing stays. Missing
  `night_lead.png`: `night.png`, then the dimmed-stage placeholder. Hide text /
  H work on all three; quitting mid-scene replays it from the first picture.
  Tested with stand-in pictures for Hazel (switches at the right lines, with
  and without Reduce Motion), `night.png` only for Opal, and none for Marina.
- The pictures fill the area under the top bar (about 1280 × 737, nearly
  16:9): only ~20 px comes off each side of a 1920 × 1080 picture.
- The Windows .exe now carries the app icon (rcedit through Wine on the build
  machine; on Windows, set Editor Settings → Export → Windows → rcedit).
- Docs: `docs/EDITING_DIALOGUE.md` ("Her night scene"), `docs/ART_LIST.md`.

## ✅ Status: round-28 — skip unread, menu slideshow, app icon, voice notice

- **Dialogue:** a "Skip unread" button next to Skip races through every line,
  read or not, up to the next reply (Skip still stops at unread lines).
- **Main menu:** until `art/menu_illustration.png` exists, a slideshow of the
  girls' places, each slowly zooming and drifting, crossfading every 9 s
  (`RosterBackdrop.cycle()`). The roster already did this for the selected
  girl.
- **App icon:** Hazel's face biting her lip (`icon.png`, `icon.ico`, from
  `tools/achievement_icons/make_app_icon.py`); the Windows presets now write
  it into the .exe (`application/modify_resources`).
- **Voice notice:** once, after the age notice (and once for existing saves):
  the voices are by amateur voice actresses, with "Turn voices off" / "Keep
  voices on" (`settings.voice_notice_seen`).
- **Words, not icons:** menu buttons, Settings, Item Shop and the dialogue
  controls are plain words; only the star, hourglass and Charm heart keep
  icon slots. The art list was trimmed to match.

## ✅ Status: round-27 — polish from the market research list

From the research task list (scope: polish only, no new girls or systems).

- **Dialogue controls** (`VNScreen.gd`): text types out (Settings: Slow /
  Normal / Fast / Instant; a click finishes the line first); **Skip** (hold
  Ctrl / RB, or the button) races through lines already read, stops at unread
  ones unless "Skip Unread Lines" is on, and always at a reply; **Auto** (A /
  Y, or the button) waits for her voice line, then a pause (Settings: Auto
  Speed); **Log** (L / LB, the button, or scrolling up) shows the last 60
  lines. Read lines are saved (`GameState.seen_lines`). Replies are a stack
  of pills over the stage, she stands a little right of centre.
- **How to Play** (`scripts/HowToPlay.gd`): a page (main menu, the chapter's
  top bar, Settings) and a one-time tip for each rule the first time it comes
  up (swap, goal, specials, combos, cursed shards, Charm, items, replies,
  out of moves, dialogue controls). The rules strip under the board is gone.
- **Puzzle HUD**, HuniePop-style: one bar under the board (moves, goal bar,
  Charm ring, items), bigger gems, her quips in a speech box at her side.
  Each quip plays at most once per attempt; laughs / sighs are rare (8%, 25 s
  cooldown, none repeated) and only once recorded.
- **Never stuck**: three losses in a row on a chapter add "Continue the
  story" to the loss screen (no stars, no chapter achievement).
- **Gallery** replays night scenes once seen (`GameState.replays`).
- **Stability**: Godot's log file is on (`user://logs`, Settings → Open log
  folder); story scenes, CGs and epilogue art have Back = Settings, which
  now offers "Leave to Roster" there (the scene plays again next time);
  Settings scrolls.
- **Balance check** (`tools/balance_bot.gd`, greedy one-move-ahead bot, no
  items, 300 runs a chapter, the starting bonus from a warm or a teasing
  reply). Nothing under 60%, so no targets changed:

| Girl | Ch | Target | Moves | Win % (warm reply) | Win % (teasing reply) | Avg score (warm) |
|---|---|---|---|---|---|---|
| Amara | 1 | 700 | 15 | 100% | 100% | 817 |
| Amara | 2 | 1030 | 15 | 97% | 91% | 1093 |
| Amara | 3 | 1250 | 16 | 90% | 74% | 1325 |
| Amara | 4 | 1350 | 18 | 84% | 64% | 1391 |
| Marina | 1 | 700 | 15 | 100% | 100% | 812 |
| Marina | 2 | 1030 | 15 | 98% | 91% | 1102 |
| Marina | 3 | 1250 | 16 | 89% | 73% | 1322 |
| Marina | 4 | 1350 | 18 | 82% | 63% | 1381 |
| Opal | 1 | 700 | 15 | 100% | 100% | 812 |
| Opal | 2 | 1030 | 15 | 96% | 93% | 1104 |
| Opal | 3 | 1250 | 16 | 89% | 74% | 1322 |
| Opal | 4 | 1350 | 18 | 83% | 65% | 1378 |
| Hazel | 1 | 700 | 15 | 100% | 100% | 811 |
| Hazel | 2 | 1030 | 15 | 98% | 92% | 1100 |
| Hazel | 3 | 1250 | 16 | 90% | 75% | 1322 |
| Hazel | 4 | 1350 | 18 | 88% | 71% | 1393 |

  Board fuzz, 10,000 boards across chapters 1-4: 0 with a ready-made match;
  1 with no legal move as built, which the game rebuilds (0 still stuck).
- **Smoke test** (`tools/smoke_test.gd`): all four stories intro → ending,
  every night replay, and the continue-the-story path: passes, no errors.
- **Demo build**: export preset "Windows (Demo)" (feature `demo`, or run with
  `-- --demo`): Hazel's intro and first chapter, then a thanks / "Wishlist
  on Steam" screen (set `Platform.STORE_URL` or `STEAM_APP_ID`). Night art
  and music are left out of its files.
- **Trailer capture**: run with `-- --trailer` (plus Godot's `--write-movie`)
  to hide the top bar, chapter HUD and placeholder tags.
- Round-24 leftovers: spark / finale CG rows dropped from the art list (each
  girl's `cg/warmth.png` is her final picture); laugh / sigh clips play on
  puzzle reactions once recorded.
- New icon slots for the artist (`docs/ART_LIST.md`): howto, log, auto,
  skip, hide, next.

## ✅ Status: round-26 — the soundtrack is in

- All seven music tracks in `audio/music/` (menu, each girl, night, ending),
  converted to .ogg and evened out to the same loudness (-20 LUFS, a little
  under the voice lines). Marina's track got a 30 ms fade at the end to stop
  the click where it loops. Composers and licences are in `data/credits.txt`
  (shown on the Credits screen; the CC BY tracks need it) and
  `docs/ART_LIST.md`. The ending track's composer still needs filling in.

## ✅ Status: round-25 — Hazel's achievements, see-through dialogue box

- **Achievements are Hazel-only for now** (16): meeting her, each chapter,
  her ending, her gift, all-warm and all-teasing playthroughs, plus the eight
  puzzle ones. The other girls' story achievements, ALL_FOUR, BOTH_ROUTES and
  the gallery ones are gone; old saves keep working (retired ids are ignored).
  Update the list in Steamworks to match (`docs/STEAM_SETUP.md`).
- **Icons:** `art/achievements/*.png`, her face zoomed in with a fitting
  expression, a colour frame and a small badge, made by
  `tools/achievement_icons/make_hazel_icons.py`.
- **Dialogue box** is see-through (62% instead of 88%).
- **Hazel's conversation sprite** sits lower and fades out at the bottom
  (`"portraitFade"` in `characters.json`, `scripts/fade_bottom.gdshader`), so
  the place her art is cut off never shows, even through the see-through box.
  Marina got the same fade, since the new box showed her cut edge too.

## ✅ Status: round-24 — Amara speaks, Hazel only blinks, bug fixes

- **Voice acting** (`autoload/Voice.gd`): a spoken line plays its clip from
  `audio/voice/<char id>/<line id>.ogg` the moment the file exists, in dialogue
  scenes and for puzzle quips (she won't start a new quip while still saying the
  last one). Narration stops her voice, and the music dips while she talks.
  Settings has **Voice Acting** (on/off) and **Voice Volume**, shown once any
  clips exist. Amara has 72 of her 80 lines; missing: `amara_end_06`/`07` and
  her laughs and sighs.
- **Recordings → clips:** `tools/voice_import/import_voice.py` finds the takes
  in each raw .wav, keeps the last one, trims it, evens the loudness and writes
  the .ogg. Hand-picked cuts are listed in `tools/voice_import/takes.json`.
- Amara's line text now matches what was recorded (10 lines), and the two unrecorded
  chatter lines (`amara_chat_04`/`05`) are gone.
- **Hazel** only blinks in her chapters (`"motion": false` and `"ambient":
  "none"` in her `live.json`). In conversations she sits higher, so her chest is
  above the dialogue box (`"portraitLift"` in `characters.json`).
- **Fixes:** a mostly-teasing playthrough crashed at the ending and replayed
  chapter 4 forever (no spark ending exists; it now falls back to hers);
  quitting mid-epilogue counted the ending on the next launch; Collector /
  Complete Gallery used fixed 8/16 counts; one-chapter power-ups were spent
  even when you left on the first frame; Testing Mode didn't clear a chapter
  on a Hammer; the voice script generator crashed on the current data.
- `BOTH_ROUTES` ("see a warm and a spark ending") can't be earned until spark
  endings exist again.

## ✅ Status: round-23 verified — Opal in the woods, Marina's reward, Amara's freedom

- **Opal** is found in the woods north of Duskhaven: her PICKLED NEWTS jar sits in a moss-lined hollow
  under an old oak, hidden there by Ambrose the forester; opening it, you kick her collection into the
  stream, and it washes down to town (Mill Bridge, Coombs, the locksmith, the taxidermist). The north
  woods are sold to an alchemist instead of the shop. Background id `slime_woods`.
- **Marina:** no wedding. Gran's comb is the thing Gran wears every Midsummer Tide; Marina offers you a
  reward for helping, strictly business (`marina_ch1_03`), and brings it up again at the end
  (`marina_ch4_06`, new).
- **Amara:** the book is her binding; burning all of it sets her free.
- Voice script 325 lines; plain-text copies per girl in `docs/voice/lines_<name>.txt`
  (`tools/voice_script/make_easy_copy.py`). Store page and art list updated.

## ✅ Status: round-22 verified — a night scene with a full-screen CG for each girl

Asked for: sex scenes at the end (dialogue, then a full CG, sweet talk, the
sex and sex talk, then the finish). I don't write explicit sex scenes, so this
round builds everything around them and leaves marked slots for the user's own
lines (the user picked that option).

- **Night scene** (`story.night` in `data/characters.json`): plays right after
  her last chapter's scene, over her full-screen CG
  (`art/characters/<id>/cg/night.png`; until it exists, her usual stage dimmed,
  tagged "CG placeholder"). Written: the sweet talk leading in, an intimate
  but non-graphic moment, and the afterwards with the fade to the morning
  after. A `"k": "slot"` line marks where the user's own part goes; the game
  never shows slot lines. Voice ids: lead-in 01–09, user's lines 10–19,
  afterwards 21–29 (e.g. `amara_night_10`).
- **Flow:** `StoryFlow._play_night()` runs between her last chapter and
  `_finish_character()`; the chapter's scene stays owed until the night ends,
  so quitting halfway replays both. Music: `audio/music/night.ogg` if present,
  else her theme.
- **CG scenes:** `VNScreen.build(..., cg_key)` / `Main.show_vn_scene(..., cg_key)`
  draw a CG full screen with no portrait, plus a "Hide text" button and the H
  key to see the whole picture.
- **Text:** age notice and menu footnote no longer say "nothing explicit";
  store notes (`STORE_PAGE.md`, `STEAM_SETUP.md`, `ITCH_SETUP.md`) explain what
  changes on Steam ("Adult Only Sexual Content", the July 2025 payment-processor
  rule) and itch.io (NSFW listing limits since July 2025) if explicit scenes or
  art are added. Art list: four night CG rows (102 to make). Voice script:
  324 lines (Amara 83, Marina 81, Opal 80, Hazel 80). Editing guide: "Her
  night scene". Only the Windows test build was rebuilt.

## ✅ Status: round-21 verified — 18+, four new stories, Opal replaces Sable

Asked for: the game is now 18+ (the last chapter's scene implies the player
sleeps with her; nothing shown); new plots for everyone (Amara summoned by
accident in the library, Marina pulled out of the water in front of her family
while searching for something, Hazel's tree nearly cut down, and a slime girl
in a jar replacing the lamia); the user's own lines worked in; more serious but
still funny, and researched so it doesn't read as AI-written; a guide to
editing lines; and a 70–80 line voice script per girl with emotions.

- **Stories:** all four rewritten in `data/characters.json` (intro, 4 chapters,
  both endings with their epilogues, gift scenes, puzzle quips). Each final
  chapter ends on a short scene and a fade; the epilogues are the morning after
  and beyond. Opal (`slime`) replaces Sable (`lamia`): new colors, gift (Old
  Glass Marble), background id `slime_woods`, music `slime.ogg`, puzzle
  frame `frames/slime.png`, achievement `ENDING_OPAL`. Amara's background is
  now `succubus_library`, her gift a beeswax candle.
- **Voice lines:** every spoken line has a stable `id` and a delivery note
  `d` (72–74 per girl). Quips are now `{"t", "d", "id"}` objects
  (PuzzleScreen still accepts plain strings).
- **Voice script:** `docs/voice/Charm_Combo_Voice_Script.xlsx` (recording
  sheet, 292 lines) and `.docx` (readable script), made from the data by
  `tools/voice_script/`; `tools/export_voice_lines.gd` (File → Run in Godot)
  re-exports `voice_lines.csv` after edits without Python.
- **18+:** one-time age notice on first launch (`AgeGateScreen.gd`,
  `settings.age_confirmed`); menu text, project description, store page text,
  Steam/itch setup notes and achievement wording updated (no more
  "guildmasters").
- **Editing:** a broken `characters.json` now shows the file and line on
  screen instead of an empty game. Test builds (`ALLOW_TESTING_MODE`) use a
  `characters.json` placed next to the .exe instead of the built-in one, so
  lines can be tried without Godot; the menu footnote says when it's in use.
- Docs: `docs/EDITING_DIALOGUE.md` (fields, where each scene is, JSON rules,
  voice IDs, and the house style / "don't sound like AI" checklist), art list
  (CG briefs for the new endings, Opal's rows). Only the Windows test build
  was rebuilt.

## ✅ Status: round-20 verified — Hazel comes alive in her chapters

Asked for: "Can you animate her? I don't really like how mermaid animation
turned out."

- **Not a flipbook this time.** Marina's loop is 60 drawn frames played forward
  and back, which shows its turnaround. Hazel is her one main sprite cut into
  layers (`art/characters/dryad/live/`: base, hair, mask, blink) and moved by a
  shader (`scripts/LiveSprite.gd`, `scripts/live_sprite.gdshader`). At rest she
  is exactly the drawn picture; nothing ever swaps.
- **What moves:** she breathes (shoulders and head rise a couple of pixels,
  fading out toward where she sits; the tree never moves), her long hair sways
  in a slow wave that runs down the strands (hidden behind her arm and thigh,
  swinging less where the tips lie on the branch), her head drifts a little,
  and she blinks every few seconds, sometimes twice (shut-eye frames painted
  from her high-res art, so hair crossing her eyes stays on top). Each motion
  has its own speed, so it never visibly loops. A few leaves drift down from
  her branch (`scripts/LeafDrift.gd`).
- **Reactions** play on the rig instead of squashing the whole picture: she
  perks up with a hair swish on good moves, sighs on sad ones, and gives a
  flustered head shake with a red flash on a cursed gem.
- **Reduce Motion** holds her still, eyes open, and hides the leaves.
- It also runs in the browser build (Marina's frames can't).
- Tools: `tools/live_rig/` (`rig_live.py` cuts the layers, `blink.py` paints the
  shut eyes, `emulate.py` previews a pose). Coordinates in them are Hazel's;
  another girl needs her own zones. Settings live in `live.json`.
- Marina is unchanged. Only the Windows test build was rebuilt.

## ✅ Status: round-19 verified — her sprite raised, and a more colorful UI

Asked for: "Make her dialogue sprite go a up. Her chest just above the
dialogue. Make menus and different windows more stylish, add colors, avoid
solid white."

- **Conversation portraits** (waist-up art) now end just above the dialogue
  box instead of standing on the screen's bottom edge, so her chest shows
  above the box (`VNScreen.PORTRAIT_H` / `PORTRAIT_LIFT`).
- **New palette** (`UITheme`): no white or cream anywhere. Cards are blush,
  rows lavender, borders rose; every menu screen sits on a lavender → blush →
  peach gradient with soft color blobs and sparkles; cards cast a faint plum
  shadow. The top bar is a plum-to-berry gradient with light text, glass pills
  for stars and Settings, and a rose-gold-violet seam under it. Buttons have a
  berry lip; ghost buttons a tinted fill; the title is berry.
- **Dialogue box**: dark plum glass edged in her color, light text, her name on
  a pill in her color (hidden for narration).
- **Pop-ups** (confirm boxes): blush window with a rose band along the top.
- Only the Windows test build was rebuilt.

## ✅ Status: round-18 verified — Hazel's art is in

Asked for: "These are dryads main sprite and emotions. Remove background and
put them in corresponding places."

- **Seven expressions** → `art/characters/dryad/<neutral|happy|shy|surprised|teasing|sad|angry>.png`.
  The white page is gone (including the gaps between hair strands, while eye
  shine and hair gloss stay), the anti-aliased edges are un-blended so no
  white rim shows on dark scenes, and all seven are aligned to the same body
  position (a few were drawn up to ~35 px off) and trimmed to one shared
  803 × 1000 canvas. They're waist-up busts, so conversations show them 480 px
  wide; her roster card frames her face with the new optional
  `"portraitFocus"` field in `data/characters.json` (0.45 for Hazel).
- **Main sprite** → a new slot, `art/characters/<id>/main.png`
  (`ArtAssets.main_sprite()`): her full figure on her tree, shown on the right
  of her chapters, flush in the bottom-right corner so the screen edge hides
  where the tree runs off the page (the branch on the left fades out), with the
  same hop/slump/wobble reactions as Marina's swim loop. Works in the browser
  build too.
- Her description and a few lines now match her art: no apron, leaf circlet or
  blossoms in her hair; when she's flustered, the green ends of her hair
  deepen instead. The art list (page and `docs/ART_LIST.md`) shows her sprites
  done: 98 images left to make.
- Only the Windows test build was rebuilt.

**Verified**: all seven expressions and the main sprite load at their sizes
and framings, her chapters show the main sprite while Marina keeps her swim
loop, and screenshots of a conversation, her roster card and a chapter.

## ✅ Status: round-17 verified — stars for losing, and a flirtier cast that starts out annoyed with you

Asked for: coins when you lose, so you can grind a little for power-ups; the
girls' dialogue reworked with Crush Crush's writing as inspiration (chosen:
flirtier, still nothing explicit, and each girl starts out annoyed with you);
and, until the final art is in, only the build being tested gets rebuilt.

**Losing pays**: running out of moves gives 1 star per 100 points scored (at
least 3), shown on the Out of Moves screen. Using +3 Moves and running out
again only tops it up, so one attempt is never paid twice. That screen now has
an **Item Shop** button, and the shop's Back ("Back to the chapter") drops you
straight into a fresh try. `PuzzleScreen.consolation_stars()` has the formula.

**New dialogue** (`data/characters.json`, every line the girls say): short,
teasing, flirty lines with running gags and a relationship "status" that climbs
each chapter ("heckler" → "understudy" → "co-star"...). Each girl now meets you
by accident: you wreck Amara's big dramatic pause, "rescue" Marina from a
relaxing float in front of her whole crew, sit on Sable's tail thinking it's a
bench, and hang your coat on Hazel's arm. The events of every ending and
epilogue, their titles, the art beats and the reply choices that pick the
final pictures are unchanged, so the art list still matches. New taglines,
quips and gift reactions too; `docs/STORE_PAGE.md` follows the new pitch.

**Builds**: only the Windows test build was rebuilt this round. The itch.io
and Steam builds get rebuilt together before publishing.

**Verified**: 238 of 238 headless checks (everything from round 16 plus the
loss payout, top-up, the shop round trip, and a check that every dialogue line
is well-formed and every girl opens annoyed); screenshots of the new Out of
Moves screen, the shop and the new first meetings.

## ✅ Status: round-16 verified — Steam achievements and friends, itch.io builds, controller play

Asked for: "are steam achievements something you can do now? and maybe any
other steam related stuff. i also plan to release on itch io so keep that in
mind". Answers: no Steam App ID yet (left blank to paste in later); itch.io
builds for Windows, Linux, Mac and the browser; controller support this round.

**Steam** (all of it switches on once `STEAM_APP_ID` is set and GodotSteam is
installed; step by step in `docs/STEAM_SETUP.md`)
- **20 achievements** (`autoload/Achievements.gd`): earned in every build,
  saved with the game (Reset Progress keeps them), listed on a new
  **Achievements** screen off the main menu, with a pop-up when you earn one.
  Story ones are re-checked from the save on start, so existing progress
  counts. Icons are drop-in: `art/achievements/<id>.png`.
- **`autoload/Platform.gd`** is the Steam bridge: it finds GodotSteam at run
  time, so the game compiles and runs the same without it. Achievements
  (including ones earned before Steam was connected; Steam's own pop-up
  replaces the game's), **rich presence** ("Chapter 2 of Marina's story",
  text in `steam/rich_presence_english.vdf`), a save when the Steam overlay
  opens, and relaunching through Steam when started outside it. Nothing is
  sent to Steam in Testing Mode.
- **Cloud saves**: Steam Auto-Cloud settings in the guide (no code).
- **Uploading**: `steam/app_build.vdf` + `steam/upload_to_steam.bat`
  (SteamPipe). `tools/make_steam_achievement_icons.gd` turns the 20 icons into
  Steam's 256×256 unlocked + grey locked pairs.
- **GodotSteam isn't bundled**: its download site is blocked from my
  workspace, so it's a two-minute install from Godot's AssetLib (guide step 2).

**itch.io and the export presets**
- Five presets in `export_presets.cfg` (now kept in git): **Windows (Steam)**,
  and **Windows / Linux / macOS / Web (itch.io)**. A `steam` or `itch` feature
  tag tells the game which store it's in; the itch.io builds never touch Steam.
- **Browser build** fixes: emoji and symbols showed as empty boxes (browsers
  have no system fonts: small emoji/symbol fonts are now bundled, with their
  licenses in Credits), sound effects failed to play (they now stream), Quit is
  hidden (a web page can't close itself), fullscreen only switches on a click,
  and Marina's swim loop shows her still art (its texture format isn't
  available in browsers). Saves persist in the browser (checked across a
  reload).
- **Mac** universal build (Intel + Apple Silicon, ad-hoc signed; players open
  it once through Privacy & Security). **Linux** x86_64 build.
- **Save folder** is now `CharmCombo` (`%APPDATA%\CharmCombo`,
  `~/.local/share/CharmCombo`, `~/Library/Application Support/CharmCombo`);
  saves from the old location are copied over once.
- `itch/push_to_itch.bat` uploads all four with butler; `itch/make_upload_zips.bat`
  makes website-upload zips. `build/` is ignored by Godot and git.

**Controller and keyboard**
- The whole game plays with a pad or keys: menus, roster, dialogue and
  choices, Settings, confirm boxes, Store, Gallery, Credits and chapters.
  In a chapter, **A** picks a gem up and a direction swaps it; **RB / X / Y**
  (or 1 / 2 / 3) use +3 Moves / Hammer / Shuffle; **B** / Backspace goes back;
  **Start** / Esc opens Settings; the right stick / PgUp / PgDn scrolls.
- A focus ring and button hints in the top bar (A / B / Start, or Enter /
  Backspace / Esc) appear only while you use keys or a pad; moving the mouse
  hides them again. Coming back to the main menu puts you on the button you
  left through.

**Art list** (`docs/ART_LIST.md` and the art list page): + 20 achievement
icons, an Achievements menu icon, Steam achievement icon specs, and the
itch.io cover and screenshots.

**Verified**: a round-16 headless suite on a scratch copy, 216 of 216 checks
(everything from round 15 plus achievements, the Steam bridge against stand-in
Steam objects for both GodotSteam versions and a failed start, rich presence,
Testing Mode, pad and keyboard play on every screen, fonts, the icon tool). All
five presets export with no errors; the Linux build boots natively; the
browser build boots in headless Chromium with a clean console, keyboard
navigation works, and saves survive a reload.

## ✅ Status: round-15 verified — bug sweep, missing features, and the full art list

Asked for: "check for any bugs, missing features, give me a list of art I need
(full body of a girl and emotion sprites, all icons, backgrounds etc.)". Three
review passes (gameplay; saves and story flow; roster, UI and story text) plus
my own checks. Everything below is fixed and covered by tests.

**Gameplay**
- **Softlock**: a normal swap whose cascades left no legal move (about 1 in
  200–480 swaps) left the board stuck with moves on the clock. Every move path
  now reshuffles a dead board for free, and Shuffle/reshuffles always produce a
  board with a move (`_fresh_playable_board()`).
- Item buttons stayed greyed out for the rest of the chapter after the first
  move; Hammer/Shuffle stayed clickable under the Out of Moves screen.
- **Hammer**: was charged when armed (tapping it twice cost two; changing your
  mind lost one). Now charged when it pops, a second tap puts it away, hammering
  a cursed shard clears it for free (it used to cost −15), and hammering a
  Rocket/Starburst sets it off.
- Keyboard/controller input could still play under the Out of Moves overlay
  (moves went negative and could still win).
- New specials could overwrite an existing special, and a board whose only moves
  were specials was reshuffled away (deleting a paid Starburst Starter).
- The swap is drawn before the gems shatter; an invalid swap clears the
  selection highlight; Reduce Motion no longer hides the toasts.

**Saves and story flow**
- **Crash-safe saves**: written to a temp file and renamed, the previous save
  kept as `save.backup.json`, an unreadable save set aside instead of being
  overwritten by the next autosave; a save `version`; older or partial saves are
  normalized (they used to break a girl's roster card and story).
- Quitting during a chapter's win scene no longer replays the chapter, pays its
  stars twice, or counts its choice twice (which could flip her ending): choices
  are stored per scene, the win is recorded before the scene, and the owed scene
  replays on the next visit.
- Quitting mid-epilogue no longer skips the epilogue forever; the finale reached
  is saved.
- The conversation choice's starting-score bonus lasts until the chapter is won
  (a retry used to drop the +110 or dodge the −40).

**Screens**
- **Gallery** rebuilt: every finale found across replays (16 in all), locked
  slots with a route hint, picture thumbnails, a counter; Back returns to the
  screen that opened it.
- **Roster**: a Replay button on finished girls (with a confirmation) to go back
  for her other endings; gifts only after you've met her; "Chapter 1 / 4" right
  after her intro (said "Not started"); Meet her / Continue / Revisit labels;
  gem icons next to Loves/Dislikes; long names ellipsize. Opening a card right
  after switching girls now plays the zoom-in (it was being cancelled, with an
  engine error).
- **Dialogue**: click anywhere, Space or Enter to continue; keyboard focus comes
  back after closing Settings; fixed a small memory leak per scene.
- **Buttons**: the hover/press animation's tweens fought each other and could
  make buttons drift; it also ignored Reduce Motion.
- **Settings**: Reset asks first; new Master Volume slider, Fullscreen toggle
  (F11 anywhere), and a Music slider once music exists. Testing Mode only shows
  while `GameState.ALLOW_TESTING_MODE` is true.
- **New**: Credits screen (with Godot's license notices, which a shipped Godot
  game must include; edit `data/credits.txt`), Quit on the main menu, Esc opens
  and closes Settings, confirmation dialogs.
- **Store**: side margins, accurate text, star icon on prices.
- **Story text**: 23 continuity and typo fixes (Marina's scenes now match her
  tail in the art, a stool that didn't exist, a lamp that had just switched off,
  and so on).
- `project.godot`: the description still said "Fernbrook High"; plain boot
  splash in the game's background color; version 1.0.0.

**Ready for art (drop-in, no code changes)**
- **Full-body sprites** are detected automatically (anything at least 1.5×
  taller than wide) and framed per screen: hung from the top in conversations,
  standing whole in the lower right of her chapters, face close-up on her
  roster card.
- **Eight CG slots per girl** (two story beats + two final pictures per route),
  with a per-route fallback image.
- **Icon slots**: logo, star, heart, hourglass, settings, play, store, gallery,
  credits, quit; one icon per gift.
- **Music** (`autoload/Music.gd`): `audio/music/menu.ogg`, one per girl, and
  `ending.ogg`, crossfading and looping; a missing track falls back to her
  theme, then the menu theme.

**Verified**: a round-15 headless suite on a scratch copy — 127 of 127 checks
(saves/backup/quarantine/migration, the whole story flow including a simulated
crash mid-scene and mid-epilogue, gallery, replay, gifts, credits, keys,
volume, items and hammer, full-body framing on all three screens, CG and icon
slots, hover animation, roster zoom, store, reset, music routing and
crossfade), plus rendered screenshots of every changed screen. No script
errors.

## ✅ Status: round-14 verified — Marina's swim loop replaces her portrait on the puzzle screen

The user dropped an `animation` folder of 80 transparent PNG frames (768×960, `frame_00665_` …
`frame_00744_`, a full-body swim idle: flowing hair, swaying tail) and asked for it to loop on the right of
her chapter instead of her portrait.

- **The clip doesn't loop on its own**: its last frame is a different pose from its first — the jump back
  is ~20× a normal frame-to-frame change — and its last ~20 frames barely move. A straight loop would
  visibly snap. So it plays forward and then back, with cosine-eased turnarounds (a baked 6.2 s cycle
  at 30 fps, stored in `art/characters/mermaid/idle/idle.json`): every display step moves at most one
  frame, including the wrap-around, so there's no seam anywhere.
- **Frames prepared** (`scratchpad/prep_idle.py`): 60 of the 80 kept, spaced evenly by amount of motion
  (which drops the near-duplicate tail frames), downscaled to 576×720 with premultiplied-alpha resampling
  (no dark edge fringes), and the body's alpha-254 "opaque" snapped to 255. Imported as BC7 (VRAM
  Compressed, high quality): ~25 MB of video memory instead of ~100 MB lossless, and faster to load.
  Loaded once per session and cached (`ArtAssets.idle_animation()`).
- **On screen**: new `FrameAnimation` (a TextureRect that steps through the sequence). Her animation is
  full-body where the portrait was waist-up, so instead of shrinking her to the 300 px sidebar she stands
  460×575 in the lower-right corner the portrait used, on a layer between the background and the UI —
  so the board, sidebar card, Charm ring and legend always draw over her, and she never blocks clicks.
- **Reactions**: the expression-portrait swaps would jump between a waist-up still and the full-body
  animation, so for her they became small effects on the animation instead — a hop on good matches, a
  slump on sad, and a quick wobble with a red flash on the cursed gem.
- **Reduce Motion** holds the first frame still (checked live, so the Settings overlay toggles it
  mid-chapter) and skips the reaction effects. The other three girls are unchanged.
- **Verified**: a round-14 headless test (36/36): 60 frames at 576×720, 30 fps from `idle.json`, a
  186-frame cycle with every entry valid and no step larger than one frame including the wrap, forward to
  the last frame and back, cached; her chapter shows the animation with nothing left in the sidebar
  portrait slot, sized 460×575 with its right/bottom edges on the sidebar's, on a layer under the whole
  UI, ignoring the mouse; it advances ~15 frames per 0.5 s, wraps, and shows the right texture; Reduce
  Motion freezes it on frame 0 and resumes when turned off; hop/flash/wobble reactions play and settle
  (including back-to-back), with no portrait swapped in; a real match still scores; the animation is
  freed with the screen and the cached frames are reused on return; and Sable (no frames) still gets her
  sidebar placeholder and expression swaps. No script errors in the engine log. Also rendered and checked
  visually, including a 3× zoom on the compressed frames.

## ✅ Status: round-13 verified — a stylized roster frame, animated girl selection, a Settings toggle, and a new dryad replacing the cat girl

1. **Roster cards have a stylized frame.** Each card's portrait + nameplate now sits in `OrnateFrame`
   (new, fully procedural — no art needed): beveled corners each set with a small faceted gem, a molding in
   her accent color with a dark outer edge and light inner edge, a gold hairline and gold corner filigree
   just inside it, a jeweled crest on the top edge, and a gem-studded divider between portrait and
   nameplate. The selected girl's frame gets a heavier band and a soft glow. Her portrait is now clipped
   exactly to its window (her hair and hands used to poke out past the strip over the old border), and the
   "Art placeholder" tag sits inside the window instead of hanging off its edge clipped down to one letter.
2. **Girl selection is animated.** The roster is now a single row of four cards along the bottom, and the
   whole screen behind them shows whichever girl is selected (`RosterBackdrop`, new): her location zoomed
   in past the screen edges, with the camera slowly flying through a looping path of pans and gentle
   re-zooms (Ken Burns style), plus a layer of floating motes that drifts farther than the scene for a bit
   of parallax. Hover a card (or tap it) to select her — the scene crossfades to hers and her name, title
   and tagline appear in a caption over it (a short settle delay means sweeping the mouse across the row
   doesn't fire a crossfade per card). Pressing Open/Revisit plays a quick zoom-in into her scene while the
   UI fades, then hands off to her story. The roster remembers who was selected, so coming back from a
   chapter reopens on her. Only Marina has real location art so far; everyone else gets `PlaceholderScene`
   (new) — a procedural stand-in in her colors (gradient, light shafts, soft bokeh), seeded per character,
   also used in her card's portrait window and tagged as a placeholder. Reduce Motion holds the camera
   still and makes switches instant.
3. **The Settings gear is a toggle.** Clicking ⚙ again while Settings is open does exactly what "← Back"
   does (both call `Main.close_settings()`), and the gear stays lit while Settings is open. Settings is now
   an overlay on top of whatever screen you were on, instead of replacing it, so closing it (either way)
   returns you exactly where you were — mid-chapter or mid-conversation included — where Back used to
   always dump you on the main menu (and opening Settings mid-chapter threw the chapter away). Changing
   Testing Mode or Reduce Motion refreshes the roster/menu underneath on close; Reset Progress swaps
   whatever was underneath for the main menu. The Settings page also got proper side margins and a
   centered column (it used to run flush against the window edges).
4. **The cat girl is replaced by a dryad: Hazel Mossgrove, Warden of the Old Grove** — an original
   character, fully clothed and wholesome like the rest of the cast: the dryad of the great hazel tree at
   the heart of Duskhaven, who can't wander more than a few streets from her tree, measures time in
   summers, and gets tiny blossoms in her hair whenever she's flustered. Loves Petal, dislikes Ember.
   Complete story written new: intro + intro choice, 4 chapters each with win dialogue and a warmth/spark
   reply (the last chapter's leads into her ending), gift (a Brass Pocket Sundial) and gift scene, quips,
   and both endings (warmth: "A Cutting from the Old Hazel"; spark: "Rival Gardeners") with full round-12
   epilogues — two art beats and a 2-option choice leading to four distinct finales. Her id is `dryad` and
   her background key is `dryad_grove` (see the art checklist). Any old save progress on the cat girl is
   simply ignored.

**Also fixed along the way:**
- **Leaving a chapter any way other than its own "← Roster" button skipped its teardown** — e.g. the
  Settings gear mid-match let the half-finished match resume on freed nodes and could even open the
  chapter-won scene on top of Settings. `Main.clear_screen()` now tears down the current screen on every
  exit (Main holds the live `PuzzleScreen`), and chapter setup's own first-frame await got the same guard.
- **Gem shapes were invisible on the board.** Every gem tile used `button_style()`'s text-button padding,
  which left the gem's icon about 8px wide — and each icon is a silhouette in exactly its tile's color. The
  board read as plain colored squares (pearl vs. crystal and moonstone vs. rune are close in hue). Tiles
  now use tight padding and draw the shape a shade darker (lighter on the dark cursed tile), tone-on-tone.
- **Top bar**: the "💞 Charm Combo" brand was word-wrapping into three stacked lines, which stretched the
  whole bar (and its star/badge/gear pills) to ~100px tall. It's one line now and the pills keep their size.
- **Ending screens**: the round-12 epilogue art panel and the ending CG panel stretched to the full window
  width with their borders running off both edges — both are now centered at a set size (the epilogue art
  bigger than before). Ending titles no longer break one word per line.
- **Epilogue text**: round 12's epilogue lines all started with "Amara: …" / "Marina: …" etc., repeating the
  name the dialogue box already shows as the speaker — removed.
- **Roster status line** now shows the finale she actually reached (same as the Gallery), not the flat
  ending title.
- **Gift buttons** show the full gift name with the price pinned on the right (long names used to force
  the text past the button), and the gift's description is in the tooltip.
- **Verified**: a round-13 headless test drove the real `Main.tscn`: the cast is exactly
  succubus/mermaid/lamia/dryad with no cat girl left; every dryad field, chapter, choice (one warmth + one
  spark reply each), ending and epilogue is well-formed with valid expressions; all FOUR of her epilogue
  branches clicked through the real screens resolve to their own finales; another character's epilogue
  still resolves after the text cleanup; the roster builds four framed cards in one row inside the window;
  the camera drifts on its own and is zoomed in; hovering a card switches the scene only after the settle
  delay, updates the caption and highlight, and frees the old shot; Open zooms in, ignores a second click,
  and lands in her intro; Reduce Motion holds the camera still; the gear opens Settings over the roster
  and closes it back onto the very same (not rebuilt) roster, as does Back; changing Testing Mode rebuilds
  the roster on close; Settings opened mid-chapter returns to the same live chapter with the board and
  moves untouched; leaving a chapter by any route tears it down; the brand is one line and the top-bar
  pills aren't stretched; gem tiles leave room for their icons; and the epilogue art panel is centered.
  104/104 checks passed, with no script errors or freed-node warnings in the engine log. The roster,
  camera motion, selection, Settings overlay, dryad screens, puzzle board and ending screens were also
  rendered and checked visually.

## ✅ Status: round-12 verified — richer post-story epilogues, plus a proactive bug audit (2 real bugs found and fixed)

A proactive "check for potential bugs" pass across the whole `scripts/` directory, plus a new feature: every
character's ending is now a real multi-beat epilogue instead of a single flat CG.

**Bugs found and fixed (found via code audit, not user-reported):**

1. **Wrong character could show up in dialogue.** `Main.show_vn_scene()` used to infer *which* character
   was talking from `current_char_id`, a field only ever written by `show_puzzle()`. Any VN scene reached
   without first opening that same character's puzzle screen — her intro (played before her first chapter
   even starts), a gift "thank you" line from the roster, or a chapter-win scene for anyone other than
   whoever's puzzle was last opened — would silently render with the WRONG name/accent/portrait/background
   (or a blank one, on the very first scene of a session), while still showing that character's actual
   dialogue text. Fixed by making `show_vn_scene()` take `char_id` as a real parameter (like
   `show_puzzle()`/`show_ending_cg()` already do) and setting `current_char_id` from it directly; all 4 call
   sites (`StoryFlow.play_intro`, `StoryFlow.on_chapter_won`, the roster's gift button, `VNScreen`'s own
   reply-chain call) now pass the correct id explicitly.
2. **A mid-match animation could touch buttons the player already navigated away from.** `PuzzleScreen`'s
   "← Roster" button is clickable at any time, including mid-animation, and `_pop_out()`'s shatter tween is
   bound to `main` (never freed) while animating the matched `cell_buttons` (which get freed the instant the
   player leaves). This is the same bug class fixed twice before in this codebase (the round-5 idle-hint
   freeze, the round-8 toast/combo tween) but had been missed here since this is a multi-target parallel
   tween. Rebinding the tween to a shorter-lived node was deliberately rejected as the fix — Godot's
   `Tween.finished` signal doesn't fire when a tween is killed (including auto-kill-on-owner-death), so that
   would risk a permanently-stalled `await` if the screen were torn down mid-flight, which is worse than the
   original bug. Fixed instead with a `_torn_down` guard flag (set by `teardown()`, already called by the
   back button) checked right after every `await` in the match-resolution chain
   (`_pop_out`/`_attempt_swap`/`_on_cell_pressed`/`_settle_and_chain`/`_resolve_loop`) plus defensively at the
   top of `_render_board()`, `_update_hud()`, and `_check_outcome()` — the last of these being the highest-
   priority spot, since it's the one that can open a brand-new screen (`StoryFlow.on_chapter_won`) on top of
   wherever the player has already navigated to.

**New feature — richer post-story epilogues.** Finishing a character's last chapter used to jump straight
to a single flat "ending CG" (title + text + placeholder art). It's now a full beat-by-beat epilogue:
dialogue → a big placeholder art reveal → more dialogue → a second placeholder art reveal → a 2-option
choice → a final placeholder screen whose title/text depends on which option was picked. All 8 endings
(4 characters × warmth/spark) got hand-written epilogue content, kept wholesome/non-explicit like everything
else in this game. Implementation notes:
- `EndingArtBeatScreen.gd` (new) renders the two mid-epilogue art-reveal beats — visually consistent with
  `EndingCGScreen` but without a title/name label, since these are transitional beats, not the resolution.
- `StoryFlow._play_epilogue()` chains the beats via nested `show_vn_scene`/`show_ending_art_beat` calls;
  `GameState.pending_epilogue_key` carries which of the 2 choice options was picked through to
  `StoryFlow._resolve_epilogue_finale()`, which records `progress.epilogue_finale` and shows that option's
  own finale CG.
- Purely additive: any ending without an `"epilogue"` block in `characters.json` still falls back to the old
  flat `show_ending_cg` flow untouched, and old saves with no `epilogue_finale` recorded still work.
- `StoryFlow.display_ending_for()` is a new shared helper — whichever finale a character actually reached
  (or her flat ending, if none) — used by both `reopen_ending()` and `GalleryScreen`, so the two never
  disagree about what "her ending" means.
- **Verified headlessly** against the real `Main.tscn` scene tree: the `current_char_id` fix (a `show_vn_scene`
  call now sets the field from its own explicit argument, confirmed across 2 different characters and by
  checking the rendered speaker name); the full epilogue chain end-to-end for BOTH choice branches on the
  same character, confirming they resolve to two genuinely different finales; that `GalleryScreen` and
  `display_ending_for()` agree with whichever finale was actually recorded; that an ending with no epilogue
  block still falls back to the flat CG cleanly; and that navigating away mid-`_pop_out` animation no longer
  throws once the in-flight tween resolves (the `_torn_down` guard). 11/11 checks passed; a full `--import`
  compile check was also clean both before and after cleaning up the test harness.

## ✅ Status: round-11 verified — roster face-crop fix, no more "stuck selected" buttons, smarter idle hints, a Charm explainer, harder early levels

A short, focused feedback round on round 10's own changes plus two standalone requests:

1. **Roster face crop actually shows her face now.** Round 10's "zoom on her face" crop assumed a
   portrait's face sits in the top third of a bust shot — for the real mermaid art, that showed mostly
   hair with her eyes cut off right at the bottom edge. `RosterScreen._card()` now anchors the crop so a
   `PORTRAIT_FACE_FOCUS` fraction (0.32) of the full scaled image lands at the *center* of the visible
   150px strip, instead of pinning the very top of the image to the top of the strip.
2. **Buttons no longer look "stuck selected" after a click.** Godot's default button focus_mode grabs
   focus on click, and `UITheme.make_primary_button()`/`make_card_button()` mapped their "focus" style to
   the same bright glow as "hover" — so after tapping something like the roster's "Open" button, it stayed
   lit up indefinitely instead of returning to normal. Since this is a mouse/touch-only UI with no
   keyboard/gamepad navigation to preserve, `UITheme._add_hover_lift()` (used by every themed button) now
   sets `focus_mode = Control.FOCUS_NONE`, so a click no longer leaves a lingering highlight.
3. **Idle hint no longer nudges you toward a broken-heart match.** `MatchEngine.find_valid_swap()` gained
   an `avoid_broken` parameter that skips past any swap whose match would include a broken-heart cell
   (still falling back to one if that's genuinely the only move left, so deadlock detection stays
   correct) — `PuzzleScreen`'s idle-hint timer now calls it with `avoid_broken = true`, so the pulsing
   hint cells never suggest deliberately costing yourself points.
4. **The board legend now explains the Charm/heart ring.** It previously only covered Rocket/Starburst/
   broken hearts — the bottom legend now adds a line on what the 💗 ring actually does (fills as you
   match gems, her favorite fastest, maxing out for a +150 Charm Burst).
5. **The first 3 chapters of every character are slightly harder.** `data/characters.json`: level 1
   650/16 → 700/15, level 2 950/16 → 1030/15, level 3 1150/17 → 1250/16 (target/moves). The 4th chapter is
   unchanged.
- **Verified headlessly**: a temporary autoload test confirmed the data bump landed correctly per level,
  that a synthetic "only move is a broken-heart match" board still returns a hint (no false deadlock)
  while a board with both a broken and a clean option returns the clean one, that the roster's real
  mermaid portrait crop is shifted down (not top-anchored), and that the "Open" button's focus_mode is
  now `FOCUS_NONE`. 17/17 checks passed; a full `--import` compile check was also clean.

## ✅ Status: round-10 verified — full-screen VN staging, roster face-zoom, item-icon contrast, board-overlay fix, per-character puzzle frame

Round 10 combined a mid-turn VN-layout request with the last two items of round 9's own follow-up
feedback list (the roster portrait and the icon/overlap/frame items had all been raised together — the
first two were tackled here alongside the VN change, the last two are what this round finishes):

- **VN screen is now full-bleed.** The old layout gave the scene a fixed ~220px art strip above a large,
  mostly-empty dialogue panel. `VNScreen.gd` was rewritten so the background + her portrait fill the
  *entire* screen (`stage` is a full-rect `Control`, portrait scaled to `PORTRAIT_W = 480` and bottom-
  anchored), with the dialogue/choice card now a compact panel docked to the bottom via a full-rect
  `VBoxContainer` with `ALIGNMENT_END` (`dock`) — the actual VN look the feedback asked for, instead of a
  cramped strip over a big empty box.
- **Roster cards zoom on her face and show her chapter background.** `RosterScreen._card()`'s portrait
  block now draws her real chapter background art (`ArtAssets.background_for(ch.bg)`) behind her portrait
  instead of a flat accent-tinted color, and the portrait itself is fit to the card's full content width
  then top-clipped to a fixed 150px strip (`clip_contents = true`) — since a bust portrait's face sits in
  its top third, this reads as a zoomed-in close-up rather than a shrunken full-body shot.
- **Item-slot icons are centered and higher-contrast.** `Button`'s default `alignment` is `LEFT`, which
  with `expand_icon = true` and no text was rendering icons off-center — fixed by setting
  `alignment`/`icon_alignment`/`vertical_icon_alignment` all to `CENTER`. The circular slot itself changed
  from an accent-filled disc (often too close in tone to the icon art) to a light "coin face" with a
  3px accent-colored ring, so every icon's own colors read clearly regardless of which character's accent
  it's on.
- **The score bar no longer overlaps the board.** `board_top_row` (moves badge + score/goal bar) used to
  float as an absolute overlay anchored *inside* `board_area`, sitting on top of the `CenterContainer`-
  centered board panel with only a few px of built-in clearance — easy to overlap on some board/window
  sizes. It's now a normal row living in `board_col`'s own document flow, positioned *before* `board_area`,
  so it always has its own dedicated space and can never overlap the board again.
- **Gem-shatter effect is more noticeable.** `_spawn_shatter()`'s piece count, shard size, and fall
  distance/speed are all bumped up, plus a quick scale-up-then-settle "pop" on spawn, so a match now reads
  as a small burst of debris rather than a few faint specks.
- **Each chapter's board now has a thematic frame, and the board itself is see-through.** `board_center`
  (a `CenterContainer`, which centers each of its children independently around the same point) now holds
  a frame Control *behind* the board panel — real art the moment `res://art/frames/<char_id>.png` exists,
  otherwise an honestly-tagged bordered placeholder — plus `ArtAssets.puzzle_frame()` for that lookup. The
  board's own well went from an opaque warm-white fill to fully transparent (`bg_color`/`border_color`
  alpha 0), so her chapter's photo background now shows through the gaps between and around the gems
  instead of a solid panel.
- **Verified headlessly**: a temporary autoload test entered the roster, a VN scene, and a real mermaid
  puzzle chapter and confirmed all of the above structurally — 4 zoomed/backgrounded portrait cards, the
  VN's full-rect clipped stage and bottom-docked choice box, item-slot button centering, `board_top_row`
  living as a sibling of `board_area` (and no longer nested inside it), and the frame node sitting behind a
  fully transparent board panel. 23/23 checks passed; a full `--import` compile check was also clean.

## ✅ Status: round-9 verified — glass-pill text backdrops fix widespread legibility over the photo backgrounds

Round 8's HUD reskin moved several labels (the "← Roster" button, the character name, the board legend,
each item slot's count) off opaque cards and onto the bare chapter background — and a screenshot from
actually playing it showed that was a mistake for readability: a fixed text/border color can't survive a
background that's light in one region and dark in another within the *same* photo (a mermaid-cove
screenshot had a pale cliffside right where the back button sat, and a mid-brown dock right under the
item counts). Every one of those spots now gets its own small translucent-dark "glass" backdrop
(`PuzzleScreen._glass_style()`/`_glass_label()`/`_photo_nav_button()`) with white text, so contrast is
guaranteed no matter what's behind it — the same trick the round-8 moves badge and score bar already
used successfully, just extended to the other text that got moved onto the background this round.

- **"← Roster"** is now a small dark pill button instead of a transparent ghost button.
- **Character name** (top-right of the top bar) now sits on its own small glass pill.
- **The board's rules legend** is now on a wide glass bar spanning the board's width, with the text
  itself switched to a light color (it was a muted gray that also disappeared against light background
  regions even with the outline it already had).
- **Item slot counts** ("×N" / "Tap a gem!") are each on their own tiny glass pill — previously they
  only had a light text outline, which doesn't help when the text itself is *also* light-toned and the
  background happens to be light too (exactly the sandy-dock case in the reported screenshot).
- **Verified headlessly**: a temporary autoload test entered a real mermaid chapter and confirmed the
  back button, name label, legend, and all 3 item-count labels are each wrapped in an opaque-enough
  (alpha > 0.3) dark backdrop with light/white text, plus a regression check that round 8's Charm ring
  and board grid are still intact.

## ✅ Status: round-8 verified — bigger sidebar sprite, Mirror-inspired HUD reskin, readability/icon/timing fixes

Round 8 was direct feedback from actually playing round 7, plus a request to
take some layout inspiration from a reference match-3 UI (a screenshot the
user shared of another game, "Mirror"). Worth being explicit about this one:
the reference art itself is not this project's style — that game's character
art is sexualized in a way that conflicts with this project's own standing
constraint (every character here stays fully clothed, non-explicit,
wholesome). What got adopted is purely **layout/UI-structure** ideas — a big
character bleeding into the background on one side, an hourglass move
counter, a bold score bar, round consumable-item slots — reskinned around
this game's own original, fully-clothed cast and its own mechanics (there's
no combat here, so there's no hero-health meter — Charm is this game's one
meter, and it gets one ring, not a health/mana pair).

- **Her portrait is now a big background figure, not a small boxed card.**
  The old ~170px-tall boxed portrait is gone; her art now fills almost the
  whole sidebar column, bottom-anchored (feet near the sidebar's bottom
  edge, sized from the actual image's own aspect ratio) so she reads as a
  large standing figure behind the HUD instead of a cramped thumbnail. Since
  the art is transparent around her, nothing needed an opaque panel behind
  it. Characters without real art yet (Amara/Sable/Momo) still get the
  emoji placeholder, just sized up to suit the bigger box.
- **The bottom-of-board rules legend is no longer flush against the window
  edge.** The whole screen is now wrapped in a `MarginContainer` (16px
  sides, 18px bottom) — previously the board area's fill-to-expand sizing
  pushed that legend text right up against the very last pixel row of the
  window with zero clearance, which is what read as "can't read the text at
  the bottom."
- **Item buttons now show their real icons**, not just text — matches the
  Item Shop, which already did this.
- **Toasts (including her reaction quips) stay on screen noticeably
  longer** — was a bare ~1s total (0.5s hold + 0.5s fade), now ~2s (1.4s +
  0.6s), enough to actually read a full quip line instead of catching half
  of it.
- **HUD reskin, Mirror-inspired**: moves-left is now a small hourglass pill
  badge over the top-left of the board; score-vs-goal is a bold pill
  progress bar across the top of the board with the numbers overlaid on it
  (replacing plain text buried in a sidebar card); the three consumable
  items (Moves/Hammer/Shuffle) are now a row of round icon slots under the
  board instead of a vertical list of wide rectangular buttons; Charm is
  now a small hand-drawn ring meter (Godot has no built-in circular
  ProgressBar — `PuzzleScreen.CharmRing`, a `Control` with a custom
  `_draw()`) sitting over the corner of her portrait, replacing the old
  linear Charm bar. The sidebar itself now holds just her name/chapter card
  plus that ring — everything else moved onto the board or under it, which
  is also what makes room for her portrait to be as big as it is now.
- **Found and fixed along the way (not user-reported)**: while testing the
  longer toast duration, leaving the puzzle screen while a toast or combo
  popup was still fading threw a "freed lambda capture" console error —
  their tweens were bound to `main` (never freed) instead of the label they
  animate, the identical footgun class as the round-5 idle-hint freeze.
  Fixed the same way: bind each tween to the label itself, so Godot
  auto-kills it the moment the label is freed by a screen transition.
- **Verified headlessly**: a temporary autoload test drove a real mermaid
  chapter — confirmed the margin wrapper, the big bottom-anchored portrait,
  the hourglass/score-bar overlay, the 3 round item slots (icons +
  `icon_max_width` capping + count labels), and the Charm ring all exist
  and render; granted a Hammer, used it to pop a cell, and confirmed score/
  charm/item-count all update correctly with zero console errors; also
  entered a chapter for a character with no real art yet (succubus) to
  confirm the emoji-placeholder fallback still works cleanly in the bigger
  box.

## ✅ Status: round-7 verified — new art integrated, shatter effect added, compiles/imports/tests/exports cleanly

Round 7 was mostly new content, not bugfixes: the user supplied real art for the
item-shop icons and for Marina the mermaid, plus asked for a satisfying
"break apart" effect when gems clear.

- **Store icons are now real art.** All 6 item-shop icons (`moves`,
  `hammer`, `shuffle`, `colorBomb`, `favorCharm`, `heartMender`) were
  replaced with user-provided 128×128 PNGs in `art/store/`, matching the
  spec size exactly. `StoreScreen.gd` already preferred `ArtAssets.store_icon()`
  over the emoji placeholder, so no code change was needed there.
- **Marina (mermaid) now has a full portrait set.** 8 expressions —
  `neutral`, `happy`, `shy`, `surprised`, `teasing`, `angry`, `sad`, and an
  `ending` CG — were added to `art/characters/mermaid/`, all 800×1000 RGBA
  matching the README's recommended portrait size. One 9th candidate image
  the user sent (a dark-cave scene where the character appears topless) was
  deliberately **not** used — it conflicts with this project's own
  fully-clothed, non-explicit standard for every character, so it was left
  out rather than silently included.
- **Marina's cove background is now real art.** `art/backgrounds/mermaid_cove.png`
  (a sunset dock scene with lanterns, shells, and a fishing net) replaces the
  placeholder background for her chapters.
- **New match-clear "shatter" effect.** Clearing a match no longer just
  fades the tile — `PuzzleScreen._spawn_shatter()` now spawns several small
  colored shard rects per matched cell that pop outward, fall with a
  gravity-style ease, spin, and fade out before freeing themselves, giving
  matches a satisfying "break into pieces" feel instead of a plain fade.
- **Combo text no longer overlaps other UI text.** It used to reuse the
  same fixed-position toast as score/status messages, so two messages could
  print on top of each other. Combos now get their own `_combo_popup()`
  that appears angled, right at the matched cells, and floats up while
  fading — and the regular toast can now stack multiple messages instead of
  clobbering itself.
- **Passive item effects (Starburst Starter, Favor Charm, Heart Mender) now
  give visible feedback.** These had no on-screen confirmation before,
  which read as "power-ups don't work" even though the underlying logic was
  fine. A chapter that starts with one active now shows a toast saying so.
- **Hammer's "armed" state is clearly distinct** from its normal state
  (highlighted style + "— pick a gem!" label), and picking a different item
  while Hammer is armed now cancels the armed state instead of leaving it
  silently active.
- **Verified headlessly**: a temporary autoload test confirmed the new
  store icons load, the mermaid portraits + ending CG load, the
  mermaid_cove background loads, and entering an actual mermaid chapter and
  triggering a real match exercises `_spawn_shatter()` end-to-end with zero
  errors and no stuck-disabled buttons.

Round 6 fixed two more bugs found by actually playing the round-5 `.exe`:

- **Dialogue choice / item text nearly invisible.** `UITheme.make_card_button()`
  (used for both VN dialogue choices and the puzzle sidebar's item buttons)
  only overrode the button's *normal*-state font color — hover, focus,
  pressed, and disabled all silently fell back to the engine's default
  theme colors, which are pale and barely readable against this button's
  light card background. Whichever button happened to be focused (a
  dialogue choice grabs focus the instant it's built) or hovered showed
  nearly-blank text. Fixed by giving every state an explicit, legible color,
  and by adding a proper "disabled" stylebox (previously missing entirely,
  so a disabled item button fell back to the flat gray default — the same
  footgun as the earlier gray-board bug) so an unusable item now reads as
  clearly muted instead of looking identical to a usable one.
- **"Can't use Hammer."** Tracing this down, the Hammer itself worked
  correctly — but once "armed" (waiting for you to tap a gem to pop) it
  looked pixel-identical to its normal state, especially with the text-color
  bug above making every item button look uniformly washed out. There was
  no real way to tell it was armed, or confirm it disarmed after you left it
  mid-arm. Added a distinct highlighted style + "— pick a gem!" label while
  armed, and a defensive fix: picking a different item while Hammer is armed
  now properly cancels the armed state instead of leaving it silently active.
- Also fixed along the way: a toast message fading out while you navigate
  away from the puzzle screen no longer prints a script error trying to
  free its already-freed label.

Round 5 fixed three bugs found by actually playing the round-4 `.exe`:

- **The game froze when returning to the roster from a puzzle chapter.**
  Root cause: the idle-hint pulse animation (`PuzzleScreen._on_idle_timeout()`)
  created its looping tween via `main.create_tween()` — bound to `main`,
  which is never freed — instead of the cell buttons it was actually
  animating. Leaving the puzzle screen while a hint was mid-pulse freed
  those buttons but left the infinite tween running against them forever.
  Fixed by binding the tween to the button itself (`btn.create_tween()`),
  so Godot auto-kills it when the button is freed, plus an explicit
  `teardown()` call on the "← Roster" button as a second safety net.
  **Verified with a headless test that reproduces the exact repro steps**
  (enter a chapter, force the idle hint to fire, leave for the roster,
  confirm the engine keeps processing frames and the roster actually
  builds) — see `test_round5_autoload.gd`'s technique in the round-4 note
  below.
- **"Combo x2!" text overlapped other on-screen text.** It was reusing the
  generic top-center toast, which could land exactly on top of a
  simultaneously-fired score/quip toast from the same match. Combo text
  now floats up from the actual matched gems with a slight angled tilt
  (`PuzzleScreen._combo_popup()`), and the generic toast (`_toast()`) now
  stacks multiple simultaneous messages vertically instead of overlapping.
- **Purchased power-ups looked like they didn't work.** Starburst
  Starter / Favor Charm / Heart Mender were applied completely silently at
  chapter start (matching the original HTML) with zero on-screen feedback.
  Each now shows a confirmation toast ("💜 Favor Charm active!") the moment
  the chapter begins.

Round 4 (Duskhaven re-theme, 4th chapter, real icons, item-weight shop,
idle-hint + auto-reshuffle) has been run through a real headless Godot 4.3
install end-to-end, not just written and hoped for:

- `godot --headless --path . --import` — a full parse/import pass — completes
  with **zero errors**.
- A dedicated round-4 smoke test (`test_round4_autoload.gd`, run as a
  temporary autoload so `GameState`/`SFX` are wired up exactly like a real
  boot — `--script` mode does not register autoloads, so plain `--script`
  testing silently can't load any of the game's own scripts) verified, all
  passing:
  - All 4 characters have exactly 4 chapters with strictly increasing
    targets, and only the last chapter's choice is `null` (the ending
    trigger).
  - All 10 gem/special icon textures and all 6 store-item icon textures
    load as real files (no emoji fallback).
  - `CharacterData.compute_weights()`'s difficulty ramp
    (`2 + chapterIdx × 1.2` cursed-shard weight) and the Favor Charm /
    Heart Mender store-item boosts produce exactly the expected numbers.
  - `MatchEngine.has_valid_move()` / `find_valid_swap()` correctly detect a
    genuine deadlock board and correctly find a real legal swap on a fresh
    board.
  - **The reported gray-board bug is fixed**: simulating two real button
    clicks and letting the move fully resolve leaves zero cell buttons
    stuck `disabled == true`.
- `godot --headless --export-release "Windows Desktop" ...` produced a
  real, self-contained `CharmCombo.exe` (~80 MB, includes the engine
  runtime).

What's **not** yet confirmed is what the game actually looks and plays like
on screen — testing ran on a display-less headless install, so this verifies
the code is correct and the build pipeline works, not the visual/interactive
feel. That first real look — and specifically confirming the roster/menu
layout fixes and the new Duskhaven art direction read well on screen — is
still yours to give it.

## How to open it

1. Install [Godot 4.3+](https://godotengine.org/download) (the standard,
   non-.NET build — this project is pure GDScript).
2. Godot → Import → select this folder's `project.godot`.
3. Press F5 (Play). It should boot to the main menu.

## What's here

```
project.godot          — engine config, autoloads, window size
icon.svg                — placeholder app icon
data/characters.json    — full story data (all 4 characters, every line of
                          dialogue, every choice, every ending) — ported from
                          the HTML prototype's CHARACTERS array, except the
                          dryad (round 13), written new for this port
autoload/
  GameState.gd          — stars, settings, per-character progress, the
                          gallery, crash-safe save/load (+ backup),
                          autosave on close/focus-lost
  SFX.gd                — tiny procedural tone-based SFX (placeholder audio)
  Music.gd              — drop-in background music (audio/music/<track>.ogg)
  Nav.gd                — keyboard / controller mode, focus rings, button
                          hints, the pad and key bindings (round 16)
  Achievements.gd       — the 20 achievements and their unlock checks
  Platform.gd           — which store build this is; the Steam bridge
                          (GodotSteam, looked up at run time)
data/credits.txt        — the Credits screen's text (edit me)
data/font_licenses.txt  — licenses for the bundled emoji/symbol fonts
assets/fonts/           — small emoji + symbol fonts (browsers have none)
docs/ART_LIST.md        — every art file the game looks for, with specs
docs/STEAM_SETUP.md     — Steam, step by step (App ID, GodotSteam,
                          achievements, cloud, rich presence, upload, Deck)
docs/ITCH_SETUP.md      — itch.io: exports, page settings, uploading
docs/STORE_PAGE.md      — starter text for the store pages
steam/                  — SteamPipe build script + upload .bat, rich
                          presence text (ignored by Godot)
itch/                   — butler upload .bat, zip maker (ignored by Godot)
tools/make_steam_achievement_icons.gd — editor script (File > Run) that
                          makes Steam's achievement icon pairs
export_presets.cfg      — Windows (Steam) + Windows/Linux/macOS/Web (itch.io)
build/                  — export output (ignored by Godot and git)
scripts/
  MatchEngine.gd        — pure match-3 rules (matching, L/T→Starburst,
                          run-of-4→Rocket, cursed pieces, gravity/refill).
                          No node/scene dependencies — easy to unit test.
  CharacterData.gd       — loads characters.json, gem color/label lookups
  ArtAssets.gd           — real-art-if-it-exists-else-placeholder lookups;
                          see "Art asset checklist" below
  UITheme.gd             — shared colors + button/panel factory functions,
                          hover/press animations, screen backdrop blobs
  StoryFlow.gd           — intro → chapter → win-scene → next chapter →
                          ending, and the warmth/spark tally that decides
                          which ending a character gets
  Main.gd                — root screen router (menu/roster/puzzle/VN/etc.),
                          plus the Settings overlay layer above the screens
  OrnateFrame.gd         — the procedural stylized frame on roster cards
  PlaceholderScene.gd    — procedural stand-in for a missing location
                          background (gradient, light shafts, bokeh)
  RosterBackdrop.gd      — the roster's slow "flying camera" over the
                          selected girl's location, crossfades, zoom-in
  FrameAnimation.gd      — plays a character's idle frames as a loop (Marina's
                          swim loop on her puzzle chapter)
  screens/
    MenuScreen.gd, SettingsScreen.gd, RosterScreen.gd, PuzzleScreen.gd,
    VNScreen.gd, EndingCGScreen.gd, EndingArtBeatScreen.gd,
    GalleryScreen.gd, StoreScreen.gd, CreditsScreen.gd,
    AchievementsScreen.gd
scenes/
  Main.tscn              — the only hand-authored scene; everything else is
                          built in code (see "Why no .tscn per screen" below)
```

## Ported faithfully

- All 4 characters' (succubus, mermaid, lamia — plus the dryad, who replaced
  the prototype's cat girl in round 13 and was written new) complete dialogue:
  intro, pre-chapter conversation choice (with the +110/−40 starting-score
  bonus), **4 chapters each** with win-scene dialogue and a warmth/spark
  choice (only the 4th/final chapter's choice is `null` — that's what
  triggers her ending), and both endings per character. The reply-choice
  screen keeps her actual last line on screen behind the reply buttons,
  instead of replacing it with a generic "What do you say?" prompt.
- Match-3 rules: 8×8 board, 6 fantasy-themed piece types (ember/moonstone/
  petal/pearl/rune/crystal) + a "cursed" piece that costs points, L/T-shaped
  and 4-in-a-row matches spawning Rockets/Starbursts, swapping a special to
  trigger it, cascading chain reactions — plus real clear/drop-in/swap
  animation, see "Animation pass" below.
- **Difficulty ramp**: each chapter is a distinct `chapterIdx` (0-3) fed into
  `CharacterData.compute_weights()`, a direct port of the original HTML's
  `computeWeights()` formula — the "cursed shard" piece gets more common as
  chapters progress (`2 + chapterIdx × 1.2`), so later chapters are
  genuinely harder, not just a bigger target number. Chapter targets/moves
  were tuned via a small offline simulation (a greedy "always take the best
  available swap" bot) so chapter 1 is comfortably easy and chapter 4 is a
  real challenge even for a strong player — see `_score_and_clear` and
  `compute_weights` doc-comments for the exact numbers.
- **Idle hint + deadlock reshuffle** (both new — the original HTML prototype
  had neither): after ~7 seconds without a move, `MatchEngine.find_valid_swap()`
  finds a real legal swap and the two cells pulse gently until you act.
  Separately, after every move settles, the board is checked for *any*
  remaining legal move at all (`MatchEngine.has_valid_move()`) — if there
  isn't one, it reshuffles for free (no move spent), so a run of bad luck
  can never fully softlock a chapter.
- Favorite/least-favorite gem per character (shown on her roster card,
  triggers her in-character quips during play).
- The sidebar sprite reacting to what just happened (angry on a cursed
  shard, surprised on a special, happy on a big combo, sad on an invalid
  swap) — currently a big reactive emoji standing in for the real
  expression art; see "What's still placeholder" below.
- Ending CG placeholder screen, reopenable from the Gallery.
- Autosave on window-close / app-paused / focus-lost.
- Testing Mode toggle (instant chapter clear + grants 99 stars).
- The full item shop, now all 6 items from the original HTML prototype:
  +3 Moves / Hammer / Shuffle (as before), plus **Starburst Starter**
  (`colorBomb` — next chapter starts with a free Starburst already on the
  board), **Favor Charm** (`favorCharm` — next chapter, her favorite gem
  shows up ~2.2× more, her least favorite ~0.4×), and **Heart Mender**
  (`heartMender` — next chapter, cursed-shard weight is cut to 35%). All
  three are one-chapter consumables, exactly like the original — see
  `CharacterData.compute_weights()` and the top of `PuzzleScreen.setup()`.
  Plus gift-giving, unchanged.

## Approximated — tune these to taste

A few numeric constants weren't visible to me in this pass of the original
file and needed reasonable placeholder values rather than exact-parity
numbers. They're all in one place and clearly commented:

- **Scoring** (`PuzzleScreen._score_and_clear`): 10 pts/normal gem, −15
  pts/cursed shard (free when the Hammer clears it), 25 pts/special-gem cell, combo multiplier
  `1 + 0.5×(comboIndex−1)`.
- **Charm** (`PuzzleScreen._score_and_clear`): +2 charm for a favorite gem,
  +1 for any other normal gem, "Charm Burst" (+150 pts, resets to 0) at 24.
- **Special-gem spawn timing**: in the original, the spawn cell for a new
  Rocket/Starburst is chosen before the rest of its run is cleared; this
  port spawns it right after the board gravity-refills instead, which is
  simpler to follow and plays the same but isn't pixel-for-pixel identical
  in *which* refilled gem gets overwritten.

None of this affects the story/dialogue side at all — only chapter pacing
(how many moves a chapter takes to clear). Playtest a chapter or two and
adjust the constants near the top of `_score_and_clear` if it feels too
fast/slow.

## What's still placeholder (by design, for this pass)

- **Character/background art**: Amara, Sable and Hazel are still a colored
  initial (roster) or a big reactive emoji (dialogue, chapters, CGs), their
  locations are procedural stand-in scenes, and no CG exists yet. Marina has
  her portraits, swim loop and cove. `docs/ART_LIST.md` lists every file;
  dropping a correctly-named file into `res://art/...` is the whole
  integration step, because every screen checks for real art first via
  `ArtAssets.gd` and only falls back to the placeholder when a file is missing.
- **Icons**: the logo and the small UI icons fall back to text/emoji.
- **Audio**: sound effects are procedural tones (`autoload/SFX.gd`); no music
  yet (drop-in slots exist, see `autoload/Music.gd`).

## Art asset checklist

**The full list is `docs/ART_LIST.md`** (also published as a page with the
same content): every file path, pixel size, what each image shows and where,
and which ones already exist — generated from the game's own data. Short
version, all paths under `res://art/`:

| What | Path | Size |
|---|---|---|
| Sprites, 7 per girl (neutral, happy, shy, surprised, teasing, sad, angry) | `characters/<id>/<expression>.png` | 1024 × 2304 full body, transparent; same canvas for all 7 |
| Story CGs, 8 per girl | `characters/<id>/cg/<ending>_beat1.png`, `_beat2.png`, `<ending>_<finale>.png` (fallback `cg/<ending>.png`) | 1920 × 1080 |
| Backgrounds | `backgrounds/succubus_library.png`, `slime_woods.png`, `dryad_grove.png` (`mermaid_cove.png` ✅) | 2560 × 1600 |
| Puzzle frames | `frames/<id>.png` | 1024 × 1016, transparent middle |
| Gift icons | `gifts/beeswaxCandle.png`, `seaGlass.png`, `goldMarble.png`, `pocketSundial.png` | 256 × 256 |
| UI icons | `ui/star.png`, `heart`, `hourglass`, `settings`, `play`, `store`, `gallery`, `credits`, `quit` | 128 × 128 |
| Logo | `ui/logo.png` | ~1200 × 375 |
| Menu illustration | `menu_illustration.png` | 2560 × 1600 |
| Idle animation (optional) | `characters/<id>/idle/idle_000.png …` + `idle.json` | e.g. 576 × 720 frames (Marina ✅) |
| Gems, Item Shop icons | `gems/*.png`, `store/*.png` | ✅ done |

Character ids: `succubus` (Amara), `mermaid` (Marina), `slime` (Opal),
`dryad` (Hazel). A missing expression falls back to her `neutral.png`, so one
file per girl is already a complete first pass. All seven of a girl's sprites
must be the same framing (all full-body or all waist-up) and canvas.

Import tip for many large frames (idle animations): set them to **VRAM
Compressed** (high quality → BC7) like Marina's; 60 lossless 576×720 frames
take ~100 MB of video memory, BC7 ~25 MB with no visible loss.

## Animation pass

Buttons everywhere now have a hover "lift" (slight scale + rise) and a
quick squash-and-spring-back on click — see `UITheme._add_hover_lift()`,
applied automatically to every button built through `UITheme.make_*_button()`.

The puzzle board now actually animates instead of just snapping between
states: matched gems shrink and fade out before the board data updates
(`PuzzleScreen._pop_out`), newly-dropped gems pop in with a slight random
stagger (`_render_board`'s `pop_cells` parameter), a swap gives both
involved gems a quick punchy scale-bounce (`_bounce`), and an invalid swap
gives them a side-to-side shake (`_shake`) instead of silently reverting.
The whole board also "deals in" with a staggered pop on chapter start.
All of it respects the existing Reduce Motion setting (skipped entirely
when that's on).

## Why no `.tscn` per screen

Every screen (menu, roster, puzzle, dialogue, etc.) is built by a plain
GDScript function that constructs its Control tree in code, rather than a
hand-authored `.tscn` per screen. I made this call because `.tscn` files
are sensitive to exact formatting and are normally generated/maintained by
the editor GUI — authoring eight of them by hand with no way to open the
editor and verify them was a much larger risk of a subtly broken scene file
than building the UI in code, which is just GDScript and fails loudly at
parse time if something's wrong. It's also a completely standard, supported
way to build Godot UI, not a hack — but if your team prefers scene-based UI
for easier visual editing, converting a screen to a `.tscn` (Editor →
"Save Branch as Scene" on the built node tree) is straightforward later.

## Before release

- Set `GameState.ALLOW_TESTING_MODE := false` in `autoload/GameState.gd` (hides
  the Testing Mode toggle and switches it off in any save, and stops the game
  reading an edited `characters.json` from beside the .exe).
- Steam: `STEAM_APP_ID` in `autoload/Platform.gd`, GodotSteam installed, and
  the Steamworks side (achievements, cloud, rich presence, depot) — all in
  `docs/STEAM_SETUP.md`. itch.io: `docs/ITCH_SETUP.md`.
- Fill in `data/credits.txt` (the Godot license notices below it are automatic).
- App icon: replace `icon.svg` (window/taskbar). For the .exe file icon and
  version info: in the export preset set `application/icon` to an `.ico`, turn
  on `application/modify_resources`, and point Godot's Editor Settings → Export
  → Windows → rcedit at `rcedit.exe` (Godot 4.3 needs it for this). Company and
  copyright fields are in the same preset.
- Still not in the game: a dialogue skip/backlog, real sound effects.

## Steam and itch.io

Both are set up as of round 16: export presets for each store, a Steam bridge
(`autoload/Platform.gd`) that switches on once GodotSteam is installed and the
App ID is set, and helper scripts in `steam/` and `itch/`. Follow
`docs/STEAM_SETUP.md` and `docs/ITCH_SETUP.md`; `docs/STORE_PAGE.md` has
starter text for both store pages.

## Next content pass

The dialogue was expanded again this round — every character now has a
genuine 4th chapter (not just a 4th target number: new win-scene dialogue,
a new mid-story choice moved to chapter 3, and the emotional finale beat
moved to chapter 4), plus extra intro lines and a full re-theme of the
world from a human high school to Duskhaven, all directly in
`data/characters.json`. Any further writing should go straight into that
JSON file; nothing about the dialogue lives in code — adding a 5th chapter
per character, for example, needs no code changes at all, since every
place that reads `ch.story.levels` already sizes itself off
`.size()` rather than assuming 3 or 4.
