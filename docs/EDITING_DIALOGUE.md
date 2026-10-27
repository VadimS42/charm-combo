# Editing the dialogue yourself

Every word the girls say, every line of narration, every reply button and every
ending lives in one text file: **`data/characters.json`**. You can change any of it
with a plain text editor. No code, no Godot knowledge needed.

Use a code editor, not Word. [VS Code](https://code.visualstudio.com/) and
[Notepad++](https://notepad-plus-plus.org/) are both free and colour the file so
mistakes stand out (VS Code also underlines them in red). Word and Google Docs
swap your straight quote marks for curly ones, which breaks the file.

## Trying your changes

**Fast way (the test build, no Godot):**

1. Copy `data/characters.json` out of the project folder (in `charm_combo_godot.zip`)
   into the folder with `CharmCombo.exe` (`CharmCombo_build`).
2. Edit that copy and save it.
3. Start the game. The menu says "using your edited characters.json" at the bottom,
   so you know it picked it up.
4. To see a scene quickly: Settings → Testing Mode on. Any match then wins the
   chapter straight away. Once her story is finished, Replay on her roster card
   starts it over (Settings → Reset Progress starts everyone over).
5. Happy with it? Copy the file back into the project's `data/` folder (or send it
   to me) so the next build has it. Delete the copy beside the exe to go back to
   the built-in lines.

This only works in test builds. Release builds always use the built-in file.

**In Godot:** edit `data/characters.json` inside the project and press Play (F5).

If you break the file, the game doesn't start the story; it shows **"The dialogue
file has a mistake in it"** with the line number. See "When it breaks" below.

## How a line looks

The four girls are in the file in this order: Amara (`"id": "succubus"`), Marina
(`"mermaid"`), Opal (`"slime"`), Hazel (`"dryad"`). Use your editor's search
(Ctrl+F) to jump to any line: search for a few words of it.

A line she speaks:

```json
{
 "k": "s",
 "t": "Stay where you are. Don't break the circle.",
 "e": "angry",
 "d": "First half commanding, then flirtatious.",
 "id": "amara_intro_07"
},
```

| Field | What it is |
|---|---|
| `"k"` | `"s"` = she says it (shown with her name), `"n"` = narration (no name, never voiced) |
| `"t"` | the text on screen. Change this freely |
| `"e"` | her picture while the line shows: `neutral`, `happy`, `shy`, `surprised`, `teasing`, `sad` or `angry` |
| `"d"` | delivery note for the voice actor. The game never shows it |
| `"id"` | the voice file name for this line. Leave it alone when you reword a line |

Narration looks the same without `"d"` and `"id"` (its `"e"` is optional):

```json
{
 "k": "n",
 "t": "She turns a page she isn't reading."
},
```

The player never speaks out loud. What the player says shows up as narration
("You ask what she means.") or as a reply button.

## Where each scene is

Inside each girl's block:

| In the file | In the game |
|---|---|
| `"tagline"`, `"role"` | the quote and the title on her roster card |
| `"story"` → `"intro"` | the scene where you meet her |
| `"story"` → `"introChoice"` | the reply buttons at the end of that scene |
| `"story"` → `"levels"` | her four chapters, in order. Each one's `"win"` is the scene after you beat it, and `"choice"` holds its reply buttons. The fourth chapter's `"win"` is the last scene of her story, ending as the two of you are alone |
| `"story"` → `"night"` | her night scene, played over her full-screen CG right after that (see "Her night scene" below) |
| `"story"` → `"endings"` | `"warmth"` and `"spark"`: the two endings. Each has a `"title"`, a summary `"text"` and an `"epilogue"` (the morning after: `"intro"`, `"middle"`, `"choice_lines"`, the last reply buttons in `"choice"`, and the closing cards in `"finales"`) |
| `"beat1_caption"`, `"beat2_caption"` | the captions under the two story pictures in each epilogue |
| `"giftLine"` | what she says when you give her the gift from the Item Shop |
| `"favQuips"`, `"leastQuips"`, `"chatQuips"` | the short pop-ups while you play: matching her favourite gem, matching one she dislikes, and general chatter |
| `"target"`, `"moves"` | a chapter's score goal and move count. Higher target or fewer moves = harder |

## Her night scene

Right after her last chapter's scene, her night scene plays over a full-screen
picture, `art/characters/<her id>/cg/night.png` (1920 × 1080). Until that file
exists, the game shows her usual background and portrait, dimmed, with a
"CG placeholder" tag. Players can press H (or the Hide text button) to see the
whole picture.

```json
"night": {
 "cg": "night",
 "lines": [ ...lead-in lines..., { "k": "slot", "t": "YOUR SCENE GOES HERE ..." }, ...afterwards... ]
}
```

The lead-in (the sweet talk) and the afterwards (lying together, then the fade to
the morning after) are written. The `"slot"` line marks where your own part of the
scene goes: the sex itself, her talk during it, and the finish. The game never shows
a slot line, so the scene already plays from the lead-in straight to the afterwards.

To write it, replace the slot line with ordinary lines, exactly like the ones around
it (`"k": "n"` for narration, `"k": "s"` for her lines). Give her spoken lines the ids
the slot suggests, for example `amara_night_10`, `amara_night_11` and so on, so they
fit between the lead-in (01 to 09) and the afterwards (21 to 29). Need more than ten?
Use `amara_night_19b`, `amara_night_19c`. The voice tools pick the new lines up
automatically.

Before you add explicit lines or art, read "Adult content" in `docs/STEAM_SETUP.md`
and `docs/ITCH_SETUP.md`: both stores treat explicit sexual content differently from
what the game has now, and you'll need to change your answers there.

## Reply buttons

```json
{
 "label": "Of course I'll help. What does it look like?",
 "stat": "warmth",
 "bonus": 110,
 "resp": [ ...her lines answering it... ]
}
```

`"label"` is the button text and `"resp"` is what happens after you click it.
Change both freely. Leave `"stat"` and `"bonus"` alone: they add up to decide which
ending she gets (more `warmth` picks give the warm ending, more `spark` the teasing
one) and set your starting score in the next chapter. The last reply
buttons in an epilogue use `"key"` instead (it picks the closing card in
`"finales"`); leave those alone too.

## Rules that keep the file working

- **Text goes between straight double quotes:** `"t": "like this"`.
- **Apostrophes are fine:** `"t": "Don't."`.
- **Double quotes inside the text** need a backslash: `"t": "She says \"no\" twice."`.
  Easier: use single quotes inside (`'no'`), as the existing lines do.
- **Commas go between items, never after the last one.** Each `{ ... }` line is followed
  by a comma unless it's the last one before a `]`. Each `"field": value` is followed
  by a comma unless it's the last before a `}`.
- **One line of dialogue = one text.** Don't press Enter inside the quotes. For a longer
  speech, add another line instead (see below).
- Keep the brackets matched: every `{` closes with `}`, every `[` with `]`.

**Adding a line:** copy a whole line from `{` to `},`, paste it right after another
line's `},`, and change the text. Give a spoken line a new `"id"` that isn't used
anywhere else (say `amara_ch2_04`, or `amara_ch2_02b` to slot one in between).
If you paste it as the last line before a `]`, remove its trailing comma and make
sure the line above it has one.

**Removing a line:** delete from its `{` to its `},`. If it was the last before a
`]`, also delete the comma after the line above it.

## When it breaks

The error screen names the line, for example
`data/characters.json, line 412: Expected ',' or '}'`. Go to that line (Ctrl+G in
both editors). The real mistake is almost always on that line or the one above:
a missing comma at the end of the previous line, a comma after the last item, or a
missing quote mark. Fix it, save, start the game again.

## Voice lines

The voice actor's script (`docs/voice/Charm_Combo_Voice_Script.xlsx` and `.docx`)
is made from this file, so after editing it's out of date until it's remade. If
you only reworded lines, the IDs still match; just send the actor the new wording.

- **With Godot only:** open `tools/export_voice_lines.gd` in Godot's Script editor and
  choose File → Run. It writes `docs/voice/voice_lines.csv` (every voiced line with its
  ID, scene, emotion and note), which opens in Excel.
- **The full spreadsheet and Word script** (needs Python with `openpyxl`, and Node.js
  with `docx`), from the project folder:

  ```
  python tools/voice_script/make_voice_script.py
  node tools/voice_script/make_voice_docx.js
  python tools/voice_script/make_easy_copy.py
  ```
  The last one writes `docs/voice/lines_<name>.txt`: each girl's lines as plain text
  with the emotion under each, easy to copy into a message.
- Or ask me to do it.

A line counts as voiced if it's `"k": "s"` or a quip.

## House style (so it doesn't read as AI-written)

The script was written and checked against these, and new lines should follow them:

- Let them dodge. People rarely answer the question they were asked, and rarely say
  how they feel ("I'm nervous"). Show it: Opal stutters, Hazel's leaves go red, Amara
  goes quiet and plain.
- Keep each girl's own rhythm. Amara: dry, exact, slow. Marina: fast, run-on when
  flustered, short when hurt. Opal: polite, counts things, apologises, then corrects
  herself. Hazel: few words, calm threats, bone-dry jokes.
- Not every line is a joke, and scenes don't end on a neat moral or a quotable zinger.
- Concrete beats clever: a returns cart, one lost shoe, four hundred and twelve buttons,
  "forty years or so to heal".
- Avoid stock phrases: smirk, "a breath she didn't know she was holding", "something
  shifted", "barely above a whisper", "don't let it go to your head", "it's not X, it's Y",
  tidy lists of three. Go easy on ellipses, and don't use dashes for drama.
- Read it out loud. If it's awkward to say, rewrite it: someone has to record it.
- Night scenes: keep each girl in her own voice even here. Amara stays dry, Marina
  talks too fast, Opal apologises and takes it back, Hazel stays calm and short. Her
  scene ends on the narration line that fades to the morning after; keep that last.
