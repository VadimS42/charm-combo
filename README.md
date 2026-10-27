# Charm Combo — Godot port

This is the start of the Steam-bound rebuild of Charm Combo in Godot 4,
carried over from the HTML/JS prototype. It's a straight structural port:
same match-3 rules, same story-flow architecture — just running on a real
engine instead of a browser tab, so it can actually be built and shipped to
Steam.

The cast is now a fantasy line-up — a succubus, a mermaid, a lamia, and a
cat girl — instead of the original four human club presidents; see
`data/characters.json` for their full arcs. See "Art asset checklist"
below for exactly what real art this needs and where to drop it in.

## ✅ Status: compiles, imports, and exports cleanly

This project has actually been run through a real Godot 4.3 install (on a
connected machine with the network access this sandbox doesn't have), not
just written and hoped for. What was verified:

- `godot --headless --path . --import` — a full parse/import pass — completes
  with **zero errors**. (This surfaced and fixed four real GDScript bugs: a
  `:=` type-inference failure in each of `MatchEngine.gd`, `StoryFlow.gd`,
  `RosterScreen.gd`, and `PuzzleScreen.gd`, all the same root cause — an
  untyped Dictionary/Array element on the right-hand side of `:=` — fixed by
  giving each variable an explicit type instead of inferring it.)
- `godot --headless --path .` — booting the actual game loop — starts clean,
  no runtime `_ready()` errors.
- A standalone headless test script exercised `MatchEngine.build_board()`,
  `analyze_matches()`, and `collapse_and_refill()`, plus `CharacterData.all()`
  loading every character's data from `characters.json` — all passed.
- `godot --headless --export-release "Windows Desktop" ...` produced a real,
  self-contained `CharmCombo.exe`.

What's **not** yet confirmed is what the game actually looks and plays like
on screen — the machine used for testing has no display attached, so this
verified that the code is correct and the build pipeline works, but not the
visual/interactive experience. That first real look is still yours to give
it — if anything looks off visually (layout, colors, a screen that doesn't
respond the way you'd expect), it's likely a UI-construction detail rather
than a logic bug, since the underlying logic has been exercised directly.

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
                          dialogue, every choice, every ending) ported
                          directly from the HTML prototype's CHARACTERS array
autoload/
  GameState.gd          — stars, settings, per-character progress, save/load,
                          autosave on close/focus-lost
  SFX.gd                — tiny procedural tone-based SFX (placeholder audio)
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
  Main.gd                — root screen router (menu/roster/puzzle/VN/etc.)
  screens/
    MenuScreen.gd, SettingsScreen.gd, RosterScreen.gd, PuzzleScreen.gd,
    VNScreen.gd, EndingCGScreen.gd, GalleryScreen.gd, StoreScreen.gd
scenes/
  Main.tscn              — the only hand-authored scene; everything else is
                          built in code (see "Why no .tscn per screen" below)
```

## Ported faithfully

- All 4 characters' (succubus, mermaid, lamia, cat girl) complete dialogue:
  intro, pre-chapter conversation choice (with the +110/−40 starting-score
  bonus), 3 chapters each with win-scene dialogue and a warmth/spark
  choice, and both endings per character. The reply-choice screen now
  keeps her actual last line on screen behind the reply buttons, instead
  of replacing it with a generic "What do you say?" prompt.
- Match-3 rules: 8×8 board, 6 fantasy-themed piece types (ember/moonstone/
  petal/pearl/rune/crystal) + a "cursed" piece that costs points, L/T-shaped
  and 4-in-a-row matches spawning Rockets/Starbursts, swapping a special to
  trigger it, cascading chain reactions — plus real clear/drop-in/swap
  animation now, see "Animation pass" below.
- Favorite/least-favorite gem per character (shown on her roster card,
  triggers her in-character quips during play).
- The sidebar sprite reacting to what just happened (angry on a broken
  heart, surprised on a special, happy on a big combo, sad on an invalid
  swap) — currently a big reactive emoji standing in for the real
  expression art; see "What's still placeholder" below.
- Ending CG placeholder screen, reopenable from the Gallery.
- Autosave on window-close / app-paused / focus-lost.
- Testing Mode toggle (instant chapter clear + grants 99 stars).
- The item shop (+3 Moves / Hammer / Shuffle) and gift-giving.

## Approximated — tune these to taste

A few numeric constants weren't visible to me in this pass of the original
file and needed reasonable placeholder values rather than exact-parity
numbers. They're all in one place and clearly commented:

- **Scoring** (`PuzzleScreen._score_and_clear`): 10 pts/normal gem, −15
  pts/broken heart, 25 pts/special-gem cell, combo multiplier
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

- **Art**: every character is a colored circle with her initial (roster)
  or a big reactive emoji (dialogue/puzzle sidebar/ending CG), and every
  background is a soft accent-colored blob glow rather than an illustrated
  scene. See "Art asset checklist" below — dropping a correctly-named file
  into `res://art/...` is the ENTIRE integration step, no code changes
  needed, because every screen already checks for real art first via
  `ArtAssets.gd` and only falls back to the placeholder when a file is
  missing.
- **Audio**: procedural tones (`autoload/SFX.gd`), not real sound design.

## Art asset checklist

Everything below is optional — the game runs and looks intentional without
any of it, via the placeholder system in `ArtAssets.gd` (every lookup there
is "does this exact file exist? if so use it, if not fall back cleanly").
Drop a file at the exact path listed and it's picked up automatically, no
code changes. PNG, transparent background where noted.

**1. Character portraits** — `res://art/characters/<id>/<expression>.png`,
one folder per character using these exact ids: `succubus`, `mermaid`,
`lamia`, `catgirl`. Recommended ~800×1000 (tall portrait crop), consistent
framing/height across all four so swapping between them mid-conversation
doesn't visually jump.

Each character needs up to 7 expression files (all optional — a missing
expression quietly falls back to that character's own `neutral.png`, so
shipping just `neutral.png` per character is a perfectly good first pass):

| File | Used when |
|---|---|
| `neutral.png` | default / most narration beats |
| `happy.png` | good outcomes, favorite-gem matches |
| `shy.png` | flustered / bashful lines |
| `surprised.png` | specials, big combos, plot beats |
| `teasing.png` | banter, rival-ish dialogue options |
| `sad.png` | invalid swap, low points |
| `angry.png` | matching the "cursed" broken piece |

These same 7 files are reused in three places automatically: the VN
dialogue stage, the puzzle screen's sidebar sprite, and the roster card
thumbnail (which always uses `neutral.png`).

**2. Ending CG** — `res://art/characters/<id>/ending.png`. One dedicated
"final scene" pose/outfit per character (falls back to her `neutral.png`
if not provided). Recommended ~1000×700, a bit more finished/celebratory
than the regular portraits since it's the payoff screen. 4 files total (one
per character) — not one per ending (warmth/spark), to keep the art budget
reasonable; the text differs by ending, the picture doesn't need to.

**3. Per-character backgrounds** — `res://art/backgrounds/<bg_key>.png`,
where `<bg_key>` is that character's `"bg"` field in `characters.json`.
Used full-bleed behind both her puzzle chapter and her VN dialogue stage.
Recommended ~1280×800 or larger, landscape, since it's shown letterboxed
behind readable UI (a translucent scrim sits on top automatically, so the
art can be busy/detailed without hurting legibility). The 4 needed:

| File | Character | Setting |
|---|---|---|
| `succubus_stage.png` | Amara Duskrose | backstage / theater, work-lamp lighting |
| `mermaid_cove.png` | Marina Waverly | pool deck / natatorium |
| `lamia_archive.png` | Sable Thornscale | basement archive room, single hanging bulb |
| `catgirl_kitchen.png` | Momo Nekoyama | home-ec kitchen, flour-dusted counters |

**4. Main menu illustration** — `res://art/menu_illustration.png`. One
hero image behind the main menu (a group shot of all four, or just an
evocative key-art piece). Recommended 1280×800+, landscape; a translucent
scrim darkens it automatically so the menu text stays readable on top.

**5. Puzzle piece icons** — `res://art/gems/<name>.png`, square, transparent
background, recommended 128×128, simple bold silhouette (they render as
small as ~44px on the board). The 7 "normal" pieces, renamed from the
original generic heart/star/leaf/drop/note/gem set to fit the fantasy cast
(mechanically identical — same 8×8 match-3 rules, just reskinned):

| File | Concept | Currently loved by | Currently disliked by |
|---|---|---|---|
| `ember.png` | small flame | — | Marina (mermaid) |
| `moonstone.png` | pale glowing gem | Momo (cat girl) | Amara (succubus) |
| `petal.png` | flower petal | — | Sable (lamia) |
| `pearl.png` | lustrous pearl | Marina (mermaid) | — |
| `rune.png` | glowing arcane symbol | Amara (succubus) | Momo (cat girl) |
| `crystal.png` | faceted teal crystal | Sable (lamia) | — |
| `cursed.png` | cracked/marred dark shard | — | (never a favorite — it's the "bad" piece, worth negative points) |

Optional, lower priority — the 3 "special" pieces created by big matches
(a plain arrow/starburst placeholder already reads fine mechanically):
`rocket_h.png`, `rocket_v.png`, `starburst.png`.

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

## Steam export

Not wired up yet — that's the natural next step once the smoke test above
passes:

1. **GodotSteam** (community Steamworks plugin) if you want native Steam
   API access (achievements, cloud saves, rich presence). Install via the
   Godot Asset Library or from godotsteam.com; it needs the Steamworks SDK
   and a Steam AppID.
2. Godot's built-in Export presets (Project → Export) to build a Windows/
   Linux/Mac binary — works without GodotSteam too if you just want a
   build to upload; add GodotSteam once you want achievements/cloud saves.
3. Steamworks side: register the app, set up depots/builds in Steamworks,
   and upload via `steamcmd` — standard for any engine, nothing
   Godot-specific there.

## Next content pass

The dialogue was recently expanded (longer intros, extra reaction lines,
ambient "chatQuips" during play, richer endings) directly in
`data/characters.json` — same content as the latest HTML version. Any
further writing should go straight into that JSON file; nothing about the
dialogue lives in code.
