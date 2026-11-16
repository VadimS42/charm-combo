# The safe-for-work version (Epic, Android)

The Epic Games Store and Google Play don't accept adult content. So the
**Windows (Epic)** and **Android** builds play a safe-for-work version of the
story. The game already handles everything that can be done without new
writing. You add the safe-for-work endings and lines below whenever you have
them; until then the fallbacks apply.

To try it on PC, run any build or the editor with `-- --sfw`. In the editor:
Project → Project Settings → Run → Main Run Args → `--sfw`.

## What the safe-for-work version does already

| Area | What happens |
|---|---|
| Night scene | Doesn't play. After her last chapter the story goes straight to her epilogue. The Gallery has no night-scene card. |
| Pictures | Night pictures never show. Every story picture uses its `_sfw` version, or a placeholder card when there isn't one. Her ending picture is `ending_sfw.png`, or her portrait when there isn't one. |
| 18+ notice | Not shown. The menu footer drops "18+". |
| Steam | Epic and Android builds never mention it: no wishlist button and no "unlocks on Steam too". |
| What's packaged | These builds ship `data/characters_sfw.json` instead of `characters.json`. They leave out the night pictures, night voice lines, night music and `ending.png` (`export_presets.cfg`). The adult material isn't in the package at all. |

## What you can add (in `data/characters.json`)

**A safe-for-work night scene, per girl.** Write the block next to her `night`. It uses the same line format as every other scene:
```json
"night_sfw": {"lines": [
  {"k": "n", "t": "You stay up talking until the candles burn down."},
  {"k": "s", "t": "...", "e": "shy", "id": "opal_nightsfw_01"}
]}
```
With no `night_sfw` there's simply no night scene.

**A safe-for-work epilogue, per ending.** Write it next to the ending's `epilogue`, in the same shape: `intro`, `beat1_caption`, `middle`, `beat2_caption`, `choice_lines`, `choice`, `finales`. You can also add `"text_sfw"` and `"title_sfw"` for the ending card.

**Any single line.** Give it a safe-for-work version, or leave it out:
```json
{"k": "s", "t": "the original line", "sfw": "the safe-for-work line", "sfw_id": "opal_end_02_sfw"}
{"k": "n", "t": "a line that only the adult version has", "sfw": false}
```
`sfw_id` is the voice clip for the new text. Without it, the line is silent in the safe-for-work version, because the recording says the original words.

**Pictures.** Put `_sfw` versions next to the originals, for example:
- `art/characters/mermaid/ending_sfw.png`
- `art/characters/mermaid/cg/warmth_beat1_sfw.png`

## Before exporting Epic or Android

Run this every time `characters.json` changes:
```
python3 tools/make_sfw_data.py
```
It writes `data/characters_sfw.json` with all of the above already applied
and the night scenes removed. That file is what those builds contain.

Russian and Chinese text for new safe-for-work lines goes through the usual
translation steps (`docs/TRANSLATING.md`).
