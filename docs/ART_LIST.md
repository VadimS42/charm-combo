# Charm Combo — art list

Every image the game looks for. Put a PNG at its path (relative to the folder with `project.godot`) and the game uses it the next time the project is opened in Godot — no code changes. Missing files keep their placeholders. Status reflects what was in `art/` when this list was generated.

**102 to make · 28 already in the game · 5 optional extras · 19 store page images (Steam and itch.io).**

Character folders use the story ids: `succubus` (Amara), `mermaid` (Marina), `slime` (Opal), `dryad` (Hazel).

## Recommended order

1. Each girl's `neutral.png` — one file puts her on every screen.
2. The other six expressions per girl.
3. Backgrounds: library, woods, grove.
4. Logo + the three HUD icons (star, heart, hourglass). Buttons are plain words and need no icons (round 28).
5. Story CGs (or first a `cg/warmth.png` per girl, which stands in for the rest).
6. Puzzle frames, gift icons, menu illustration.
7. Achievement icons.
8. App icon + store page images (Steam and itch.io).

## Specs

- **Sprites:** 1024 × 2304 px, transparent PNG. Head to toe (tail for Marina), centered, 60–120 px of empty space above her head. All seven files share the exact same canvas and body position; only the face (and hands, if you like) change. Conversations show her 1180 px tall hanging from the top of the screen (head to about mid-thigh visible above the dialogue box). Her chapters show her whole, 575 px tall, in the lower right. Her roster card zooms in on her face, which should sit about 9–11% down from the top of the canvas. Waist-up busts work too (Hazel's: all seven on one shared canvas, about 800 × 1000): conversations show them 480 px wide standing on the bottom edge, and her roster card uses `portraitFocus` in `data/characters.json` (how far down the picture her face is) if it sits lower than usual. With busts, add a `main.png` full figure for her chapters (see each girl's world table). A main sprite can also be turned into a live sprite (breathing, swaying hair, blinking) without drawing anything more, as Hazel's was in round 20; a high-res copy of it on its own page helps with the blink.
- **CGs:** 1920 × 1080 px (16:9), opaque PNG. Shown at 900 × 506 for the two story beats, 760 × 400 for the final picture (a little is cropped off the top and bottom, so keep faces inside the middle 90%), and as 252 × 142 thumbnails in the Gallery. The player is never shown from the front: keep "you" off camera, or as hands or a back view.
- **Backgrounds:** 2560 × 1600 px (16:10), opaque PNG; 1920 × 1200 is the minimum. Shown full screen behind her chapters and conversations under a light scrim, and on the roster with a slow zooming camera (up to ~1.6×, hence the extra size). Keep the bottom quarter simple: the dialogue box and item buttons sit there.
- **Puzzle frames:** 1024 × 1016 px, transparent PNG, shown at 512 × 508 behind the gem board. Put the ornament in the outer 72 px band; the middle 880 × 872 must stay transparent (or a very faint texture), because it shows between the gems.
- **Gift icons:** 256 × 256 px, transparent PNG. Shown at 24 px on her gift button, so keep the silhouette bold.
- **UI icons:** 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px.
- **Achievement icons:** 256 × 256 px PNG, a round or shield-shaped badge on a transparent (or filled) background, no text. The game shows it at 56 px on its Achievements screen and greys out locked ones by itself; Steam shows it at 64 px. Draw only the unlocked version: tools/make_steam_achievement_icons.gd makes the grey “locked” copies Steam also wants.

## Amara Duskrose — Succubus, summoned by mistake (`succubus`)

Look: small curled horns, a heart-tipped tail, dark wings she keeps folded; dressed for somewhere much nicer than a library: a high-collared black evening dress lined in deep pink; a little chalk dust on the hem. Colors — accent #FF5FA8, hair #3A1F33 / shade #241220, skin #F3D2C9, eyes #FF8FCE, outfit #2B1730, trim #FF5FA8.

### Sprites

| Expression | File | When it shows | Status |
|---|---|---|---|
| neutral | `art/characters/succubus/neutral.png` | Her default: narration, plain lines, her roster card, her chapters at rest. (Required — every other expression falls back to this one.) | To make |
| happy | `art/characters/succubus/happy.png` | Warm or excited lines; combos of 2+ in her chapters. | To make |
| shy | `art/characters/succubus/shy.png` | Flustered, caught-off-guard lines. | To make |
| surprised | `art/characters/succubus/surprised.png` | Surprise beats; a special gem (Rocket/Starburst) going off in her chapters. | To make |
| teasing | `art/characters/succubus/teasing.png` | Banter and flirting. | To make |
| sad | `art/characters/succubus/sad.png` | Quiet or hurt lines; chapters: a swap that doesn't match. | To make |
| angry | `art/characters/succubus/angry.png` | Annoyed lines; chapters: a cursed shard in your match. | To make |

### Story CGs

Her **night CG** fills the screen behind the dialogue box for her whole night scene, right after her last chapter: keep faces and anything important in the upper two-thirds (players can press H to hide the text and see all of it). How explicit it is is your call, but explicit art changes your store answers (see `docs/STORE_PAGE.md`). The story beats after it are the morning after.

| File | Moment | What to draw | Status |
|---|---|---|---|
| `art/characters/succubus/cg/night.png` | Her night scene (full screen, behind the dialogue, after her last chapter) | The reading room at night with the door shut. The only light is the candle in your chalk circle on the floor. Amara on the reading table, wings half open, her black-and-pink evening dress with its long row of tiny hooks down the back; you only as hands, a shoulder or a back view. 1920 × 1080. | To make |
| `art/characters/succubus/cg/warmth_beat1.png` | Story beat 1 (Caption under it in the game: “The reading room at dawn: a burnt-out candle in a smudged chalk circle, your jacket folded into a neat square on the returns cart.”) | Dawn light through tall library windows onto the reading room floor: the smudged chalk circle, a candle burnt down to a puddle of wax, your jacket folded into a perfect square on the returns cart. No people; the room tells it. | To make |
| `art/characters/succubus/cg/warmth_beat2.png` | Story beat 2 (Caption under it in the game: “Her corrections in red pencil, all over the loose page that started it.”) | Close-up: the loose page with the summoning circle, covered in Amara's neat red-pencil corrections and arrows, one corner torn off where her name was; her clawed hand and the pencil at the edge of frame. | To make |
| `art/characters/succubus/cg/warmth.png` | Her ending — final picture — “After Hours” (also stands in for any story beat above that's missing) | Her library card has your address on it in small, furious handwriting. She moves in with forty candles and opinions about your bookshelf, which she reorganises by how much she disliked each book. Your favourite goes on t… | To make |


### Her world

| Asset | File | What to draw / spec | Status |
|---|---|---|---|
| Background | `art/backgrounds/succubus_library.png` | Duskhaven Public Library's reading room at night: tall shelves, a returns cart, long reading tables, the gas lamps out, a fireplace, moonlight through tall windows, a chalk circle on the floorboards. 2560 × 1600 px (16:10), opaque PNG; 1920 × 1200 is the minimum. Shown full screen behind her chapters and conversations under a light scrim, and on the roster with a slow zooming camera (up to ~1.6×, hence the extra size). Keep the bottom quarter simple: the dialogue box and item buttons sit there. | To make |
| Puzzle frame | `art/frames/succubus.png` | An old book binding: tooled leather corners, gilt edges, a ribbon bookmark and a few chalk marks. 1024 × 1016 px, transparent PNG, shown at 512 × 508 behind the gem board. Put the ornament in the outer 72 px band; the middle 880 × 872 must stay transparent (or a very faint texture), because it shows between the gems. | To make |
| Gift icon — Hand-Dipped Beeswax Candle | `art/gifts/beeswaxCandle.png` | A tall honey-coloured beeswax candle, lit. 256 × 256 px, transparent PNG. Shown at 24 px on her gift button, so keep the silhouette bold. | To make |
| Main sprite | `art/characters/succubus/main.png` | Optional: one full-figure picture shown on the right of her chapters, 575 px tall in the bottom-right corner, in place of an idle animation. Worth it if her expressions are waist-up busts, and it can be turned into a live sprite (breathing, hair sway, blinking) like Hazel's. Transparent PNG, about 730 × 1000; anything running off the page should touch the right or bottom edge. | Optional |
| Ending portrait | `art/characters/succubus/ending.png` | A celebratory pose. Transparent PNG, any size. Only a stand-in inside the final-picture frame while her CGs are missing; skip it once the CGs exist. | Optional |

## Marina Waverly — Mermaid of Saltwick Cove (`mermaid`)

Look: long wavy teal hair with coral-red streaks and a few tiny shells tucked in it, pointed ears, amber eyes, freckles; a shell necklace and scallop-shell top; a teal-scaled tail with a coral-pink tail fin (see her existing art in art/characters/mermaid). Colors — accent #2FB6C9, hair #0E5C73 / shade #083E4D, skin #F6DFCB, eyes #2FB6C9, outfit #0E5C73, trim #7FE8D6.

Marina already has all seven as waist-up portraits (800 × 1000). Full-body versions (tail as in her swim animation) keep her consistent with the others — replace all seven together.

### Sprites

| Expression | File | When it shows | Status |
|---|---|---|---|
| neutral | `art/characters/mermaid/neutral.png` | Her default: narration, plain lines, her roster card, her chapters at rest. (Required — every other expression falls back to this one.) | Redo full-body |
| happy | `art/characters/mermaid/happy.png` | Warm or excited lines; combos of 2+ in her chapters. | Redo full-body |
| shy | `art/characters/mermaid/shy.png` | Flustered, caught-off-guard lines. | Redo full-body |
| surprised | `art/characters/mermaid/surprised.png` | Surprise beats; a special gem (Rocket/Starburst) going off in her chapters. | Redo full-body |
| teasing | `art/characters/mermaid/teasing.png` | Banter and flirting. | Redo full-body |
| sad | `art/characters/mermaid/sad.png` | Quiet or hurt lines; chapters: a swap that doesn't match. | Redo full-body |
| angry | `art/characters/mermaid/angry.png` | Annoyed lines; chapters: a cursed shard in your match. | Redo full-body |

### Story CGs

Her **night CG** fills the screen behind the dialogue box for her whole night scene, right after her last chapter: keep faces and anything important in the upper two-thirds (players can press H to hide the text and see all of it). How explicit it is is your call, but explicit art changes your store answers (see `docs/STORE_PAGE.md`). The story beats after it are the morning after.

| File | Moment | What to draw | Status |
|---|---|---|---|
| `art/characters/mermaid/cg/night.png` | Her night scene (full screen, behind the dialogue, after her last chapter) | The boathouse at night: tarred beams, a heap of old sails in the corner, moonlight coming in over the slipway from the cove. Marina still wet from the water, hair dripping, her teal tail trailing down the slipway into the sea; you only as hands, a shoulder or a back view. 1920 × 1080. | To make |
| `art/characters/mermaid/cg/warmth_beat1.png` | Story beat 1 (Caption under it in the game: “The boathouse slipway at sunrise, two sets of clothes drying on the rail.”) | Sunrise over the boathouse slipway: dark water, a heap of old sails, two sets of clothes hung to dry on the rail; Marina's tail fin breaking the water at the edge of frame. | To make |
| `art/characters/mermaid/cg/warmth_beat2.png` | Story beat 2 (Caption under it in the game: “Gran at the Midsummer Tide, her pearl comb in her hair.”) | The Midsummer Tide at the cove: the whole family out on the rocks under a low summer moon, lanterns floating on the water, Gran in the middle with the nine-pearl comb in her hair, pretending not to notice everyone watching; Marina at the edge, eyes wet. | To make |
| `art/characters/mermaid/cg/warmth.png` | Her ending — final picture — “High Water” (also stands in for any story beat above that's missing) | Gran wears the comb at the Midsummer Tide and never finds out it was lost. Marina tells her anyway, a month later, and Gran laughs so hard she has to be helped onto a rock. Marina tells the story of how you met at every … | To make |


### Her world

| Asset | File | What to draw / spec | Status |
|---|---|---|---|
| Background | `art/backgrounds/mermaid_cove.png` | Saltwick Cove: the pier, lanterns, rocks and water at dusk. Have (1280 × 800). Optional: a 2560 × 1600 version would stay sharper under the roster's zoom. | Have |
| Puzzle frame | `art/frames/mermaid.png` | Driftwood and rope, with shells, sea glass and a bit of net. 1024 × 1016 px, transparent PNG, shown at 512 × 508 behind the gem board. Put the ornament in the outer 72 px band; the middle 880 × 872 must stay transparent (or a very faint texture), because it shows between the gems. | To make |
| Gift icon — Frosted Sea-Glass Pendant | `art/gifts/seaGlass.png` | A frosted chip of sea glass on a plain cord. 256 × 256 px, transparent PNG. Shown at 24 px on her gift button, so keep the silhouette bold. | To make |
| Idle animation | `art/characters/mermaid/idle/idle_000.png …` | A gentle looping idle (breathing, hair or tail sway). Have — 60 frames, 576 × 720, looping (round 14). | Have |
| Ending portrait | `art/characters/mermaid/ending.png` | A celebratory pose. Transparent PNG, any size. Only a stand-in inside the final-picture frame while her CGs are missing; skip it once the CGs exist. | Have |

## Opal — Slime, formerly of a jar (`slime`)

Look: a slime woman, clearly an adult: her whole body is translucent, pearly lilac jelly that catches pink and green glints like an opal; long hair-like jelly falling in soft drips; one or two of her collected treasures visible floating inside her (a brass button, a small key); wears an oversized moss-green cardigan from the shop's lost-and-found, every button different; when she's flustered, pink spreads through her like dye in water. Colors — accent #9B7EF0, hair #D9CCF7 / shade #A996E8, skin #E9E1FB, eyes #5B4BC4, outfit #6E7F4E, trim #F2B8DA.

### Sprites

| Expression | File | When it shows | Status |
|---|---|---|---|
| neutral | `art/characters/slime/neutral.png` | Her default: narration, plain lines, her roster card, her chapters at rest. (Required — every other expression falls back to this one.) | To make |
| happy | `art/characters/slime/happy.png` | Warm or excited lines; combos of 2+ in her chapters. | To make |
| shy | `art/characters/slime/shy.png` | Flustered, caught-off-guard lines. | To make |
| surprised | `art/characters/slime/surprised.png` | Surprise beats; a special gem (Rocket/Starburst) going off in her chapters. | To make |
| teasing | `art/characters/slime/teasing.png` | Banter and flirting. | To make |
| sad | `art/characters/slime/sad.png` | Quiet or hurt lines; chapters: a swap that doesn't match. | To make |
| angry | `art/characters/slime/angry.png` | Annoyed lines; chapters: a cursed shard in your match. | To make |

### Story CGs

Her **night CG** fills the screen behind the dialogue box for her whole night scene, right after her last chapter: keep faces and anything important in the upper two-thirds (players can press H to hide the text and see all of it). How explicit it is is your call, but explicit art changes your store answers (see `docs/STORE_PAGE.md`). The story beats after it are the morning after.

| File | Moment | What to draw | Status |
|---|---|---|---|
| `art/characters/slime/cg/night.png` | Her night scene (full screen, behind the dialogue, after her last chapter) | Your bedroom with the lamp turned right down. The only light is Opal's own soft lilac glow, brighter wherever she's being touched; her empty jar on the shelf in the background with its lid off. You only as hands, a shoulder or a back view. 1920 × 1080. | To make |
| `art/characters/slime/cg/warmth_beat1.png` | Story beat 1 (Caption under it in the game: “Morning light through the bedroom curtains, and someone translucent and lilac curled over the covers.”) | Your bedroom in morning light: Opal spread over the covers like a translucent lilac blanket, sunlight shining through her, a few treasures floating inside her; you as a shape under the covers. Cosy, not explicit. | To make |
| `art/characters/slime/cg/warmth_beat2.png` | Story beat 2 (Caption under it in the game: “Opal at the baker's counter, a loaf under one arm and a stray button in her hand.”) | The bakery: Opal at the counter in her oversized cardigan, a loaf under one arm, proudly holding up a button she found; the baker leaning on the counter, patient. | To make |
| `art/characters/slime/cg/warmth.png` | Her ending — final picture — “A Quiet Place” (also stands in for any story beat above that's missing) | Opal moves in properly. Her collection grows a second shelf, then a third: things you've dropped, things your friends have dropped, the ticket from your first evening out together. The jar lives under the bed. She uses i… | To make |


### Her world

| Asset | File | What to draw / spec | Status |
|---|---|---|---|
| Background | `art/backgrounds/slime_woods.png` | The woods north of Duskhaven in late autumn: a fast brown stream, an old oak with a moss-lined hollow between its roots, a big glass jar sealed with wax (PICKLED NEWTS, DO NOT OPEN), fallen leaves, low gold light through the trees. 2560 × 1600 px (16:10), opaque PNG; 1920 × 1200 is the minimum. Shown full screen behind her chapters and conversations under a light scrim, and on the roster with a slow zooming camera (up to ~1.6×, hence the extra size). Keep the bottom quarter simple: the dialogue box and item buttons sit there. | To make |
| Puzzle frame | `art/frames/slime.png` | Moss, oak roots and fallen leaves round the border, with buttons, keys and a little glass jar tucked in among them. 1024 × 1016 px, transparent PNG, shown at 512 × 508 behind the gem board. Put the ornament in the outer 72 px band; the middle 880 × 872 must stay transparent (or a very faint texture), because it shows between the gems. | To make |
| Gift icon — Old Glass Marble | `art/gifts/goldMarble.png` | A clear glass marble with a ribbon of gold twisted through it. 256 × 256 px, transparent PNG. Shown at 24 px on her gift button, so keep the silhouette bold. | To make |
| Main sprite | `art/characters/slime/main.png` | Optional: one full-figure picture shown on the right of her chapters, 575 px tall in the bottom-right corner, in place of an idle animation. Worth it if her expressions are waist-up busts, and it can be turned into a live sprite (breathing, hair sway, blinking) like Hazel's. Transparent PNG, about 730 × 1000; anything running off the page should touch the right or bottom edge. | Optional |
| Ending portrait | `art/characters/slime/ending.png` | A celebratory pose. Transparent PNG, any size. Only a stand-in inside the final-picture frame while her CGs are missing; skip it once the CGs exist. | Optional |

## Hazel Mossgrove — Dryad of the old hazel (`dryad`)

Look: long straight hair that fades from pale gold at the crown to leaf green at the tips, amber eyes, a sleeveless leaf-green dress with a crossed halter neck; in her full-figure art she sits on a great branch of her tree, her legs turning into its roots below the knee (see art/characters/dryad). Colors — accent #5E9E45, hair #EBDDB2 / shade #8DB46E, skin #F1D2BE, eyes #C98A2E, outfit #B7C982, trim #6E8F4A.

### Sprites

| Expression | File | When it shows | Status |
|---|---|---|---|
| neutral | `art/characters/dryad/neutral.png` | Her default: narration, plain lines, her roster card, her chapters at rest. (Required — every other expression falls back to this one.) | Have |
| happy | `art/characters/dryad/happy.png` | Warm or excited lines; combos of 2+ in her chapters. | Have |
| shy | `art/characters/dryad/shy.png` | Flustered, caught-off-guard lines. | Have |
| surprised | `art/characters/dryad/surprised.png` | Surprise beats; a special gem (Rocket/Starburst) going off in her chapters. | Have |
| teasing | `art/characters/dryad/teasing.png` | Banter and flirting. | Have |
| sad | `art/characters/dryad/sad.png` | Quiet or hurt lines; chapters: a swap that doesn't match. | Have |
| angry | `art/characters/dryad/angry.png` | Annoyed lines; chapters: a cursed shard in your match. | Have |

### Story CGs

Her **night CG** fills the screen behind the dialogue box for her whole night scene, right after her last chapter: keep faces and anything important in the upper two-thirds (players can press H to hide the text and see all of it). How explicit it is is your call, but explicit art changes your store answers (see `docs/STORE_PAGE.md`). The story beats after it are the morning after.

| File | Moment | What to draw | Status |
|---|---|---|---|
| `art/characters/dryad/cg/night.png` | Her night scene (full screen, behind the dialogue, after her last chapter) | Night on the moss under the old hazel. Her branches knitted together overhead, rain beading on the leaves and not coming through; her gold-to-green hair spread over the moss, legs turning into roots below the knee. You only as hands, a shoulder or a back view. 1920 × 1080. | To make |
| `art/characters/dryad/cg/warmth_beat1.png` | Story beat 1 (Caption under it in the game: “The old hazel at dawn, in full blossom, in May.”) | The old hazel by the millrace at dawn, its east side covered in out-of-season blossom, petals scattered on the moss below over a blanket and a pair of boots. | To make |
| `art/characters/dryad/cg/warmth_beat2.png` | Story beat 2 (Caption under it in the game: “A sapling beside the new millrace, a ribbon tied round it.”) | A young sapling beside the new millrace with a ribbon tied round it; Hazel's hand resting on its leaves. | To make |
| `art/characters/dryad/cg/warmth.png` | Her ending — final picture — “Out of Season” (also stands in for any story beat above that's missing) | The millrace runs and the old hazel keeps her roots. You plant another hazel beside the new channel, and it grows faster than it has any right to, leaning towards the old tree as if it's listening. You sleep in the grove… | To make |


### Her world

| Asset | File | What to draw / spec | Status |
|---|---|---|---|
| Background | `art/backgrounds/dryad_grove.png` | The old hazel by the millrace: an enormous ancient hazel tree at the edge of a mossy grove, its roots bending the stone back wall of a watermill, a new channel of water running past, ferns and a little footbridge. 2560 × 1600 px (16:10), opaque PNG; 1920 × 1200 is the minimum. Shown full screen behind her chapters and conversations under a light scrim, and on the roster with a slow zooming camera (up to ~1.6×, hence the extra size). Keep the bottom quarter simple: the dialogue box and item buttons sit there. | To make |
| Puzzle frame | `art/frames/dryad.png` | Living hazel branches and leaves with a few white blossoms. 1024 × 1016 px, transparent PNG, shown at 512 × 508 behind the gem board. Put the ornament in the outer 72 px band; the middle 880 × 872 must stay transparent (or a very faint texture), because it shows between the gems. | To make |
| Gift icon — Brass Pocket Sundial | `art/gifts/pocketSundial.png` | A folding brass pocket sundial. 256 × 256 px, transparent PNG. Shown at 24 px on her gift button, so keep the silhouette bold. | To make |
| Main sprite | `art/characters/dryad/main.png` | Her full figure, sitting on her tree. Shown on the right of her chapters, 575 px tall, flush in the bottom-right corner (her conversations and roster card use the seven expressions). Have — 730 × 1000, transparent, the cut-off branch fading out on the left. | Have |
| Live sprite | `art/characters/dryad/live/` | Her main sprite brought to life (breathing, hair sway, blinking, falling leaves): base.png, hair.png, mask.png, blink.png and live.json, all cut from `main.png` and her high-res art with `tools/live_rig/`. Nothing to draw. Have (round 20); replaces a frame-by-frame idle. | Have |
| Ending portrait | `art/characters/dryad/ending.png` | A celebratory pose. Transparent PNG, any size. Only a stand-in inside the final-picture frame while her CGs are missing; skip it once the CGs exist. | Optional |

## Menu art, logo and icons

| Asset | File | Where / spec | Status |
|---|---|---|---|
| Main menu illustration | `art/menu_illustration.png` | Key art: Duskhaven at twilight with the four of them, or the town with their four places (library, cove, woods, grove). 2560 × 1600 px (16:10), opaque PNG. Shown full screen behind the main menu under a light 55% scrim; the logo and buttons sit in the middle, so keep the center calm. | To make |
| Logo | `art/ui/logo.png` | The “Charm Combo” wordmark. About 1200 × 375 px, transparent PNG. Shown up to 480 × 150 on the main menu and 36 px tall in the top bar, so it must read small too. | To make |
| Icon — star | `art/ui/star.png` | Stars (the currency): top bar counter, prices on gifts and in the Item Shop. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — heart | `art/ui/heart.png` | The middle of the Charm ring in her chapters. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — hourglass | `art/ui/hourglass.png` | Moves left, in her chapters. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |

## Achievement icons (16)

Hazel only for now, made from her expression art (her face, zoomed in) by `tools/achievement_icons/make_hazel_icons.py`. Re-run it after changing her expressions.

| Achievement | Unlocks when | File | Icon | Status |
|---|---|---|---|---|
| Don't Even Think About It | Meet Hazel instead of cutting her tree down. | `art/achievements/hazel_meet.png` | angry, moss green | Done |
| A Lovely Trench | Clear Hazel's first chapter. | `art/achievements/hazel_ch1.png` | teasing, leaf green, badge I | Done |
| Leaves Going Red | Clear Hazel's second chapter. | `art/achievements/hazel_ch2.png` | shy, autumn red, badge II | Done |
| Out in the Storm | Clear Hazel's third chapter. | `art/achievements/hazel_ch3.png` | sad, storm blue, badge III | Done |
| Putting Down Roots | Reach Hazel's ending. | `art/achievements/ending_hazel.png` | happy, gold | Done |
| Keeping Time | Give Hazel the Brass Pocket Sundial. | `art/achievements/hazel_gift.png` | surprised, brass | Done |
| Soft as Moss | Finish Hazel's story picking every warm reply. | `art/achievements/hazel_sweet.png` | shy, rose pink | Done |
| Splinters | Finish Hazel's story teasing her in every reply. | `art/achievements/hazel_tease.png` | angry, plum | Done |
| Chain Reaction | Set off a x3 combo. | `art/achievements/combo_3.png` | happy, teal, badge x3 | Done |
| Avalanche | Set off a x5 combo. | `art/achievements/combo_5.png` | surprised, deep teal, badge x5 | Done |
| Starstruck | Make a Starburst. | `art/achievements/make_starburst.png` | surprised, amber, star badge | Done |
| Mega Blast | Swap two special gems together. | `art/achievements/mega_blast.png` | surprised, orange, burst badge | Done |
| Irresistible | Fill the Charm ring for a Charm Burst. | `art/achievements/charm_burst.png` | shy, pink, heart badge | Done |
| With Moves to Spare | Clear a chapter with 5 or more moves left. | `art/achievements/moves_left_5.png` | teasing, blue, badge +5 | Done |
| Shard Smasher | Clear a cursed shard with the Hammer. | `art/achievements/shard_smash.png` | angry, violet, cross badge | Done |
| Window Shopping | Buy something in the Item Shop. | `art/achievements/first_purchase.png` | happy, lilac, star badge | Done |

## Launch

| Asset | File | Notes | Status |
|---|---|---|---|
| App icon | `icon.png` | Hazel's face biting her lip, made by `tools/achievement_icons/make_app_icon.py` (round 28). Redraw only for a cleaner version, readable at 16 px. | Done |
| Windows .exe icon | `icon.ico` | Made from the app icon by the same script (16–256 px); the Windows export presets write it into the .exe. | Done |

### Steam (uploaded in Steamworks)

Capsules: game art + logo only — no review scores, awards or sale text.

| Image | Size (px) | Used for |
|---|---|---|
| Header capsule | 920 × 430 | Top of the store page, search, recommendations. |
| Small capsule | 462 × 174 | Lists and search; the logo must still read at 120 × 45. |
| Main capsule | 1232 × 706 | Front-page carousel and wishlist emails. |
| Vertical capsule | 748 × 896 | Seasonal sale pages. |
| Page background | 1438 × 810 | Optional ambient art behind the store page. |
| Screenshots | 1920 × 1080 | At least 5, 16:9, straight from the game. |
| Library capsule | 600 × 900 | The game's cover in players' libraries. |
| Library header | 920 × 430 | Falls back to the header capsule if not set. |
| Library hero | 3840 × 1240 | Art only, no text; keep the key part in the center 860 × 380. |
| Library logo | up to 1280 × 720 | Transparent PNG, the title logotype only. |
| App icon | 184 × 184 | JPG, used in the library list, chat and notifications. |
| Shortcut icon | 256 × 256 | ICO or PNG, for desktop shortcuts. |
| Event cover | 800 × 450 | For announcements and events (later). |
| Event header | 1920 × 622 | Optional, top of an event page (later). |
| Achievement icons | 256 × 256 | 20 unlocked + 20 locked. The unlocked ones are the game's own art/achievements files; tools/make_steam_achievement_icons.gd makes both sets ready to upload. |

### itch.io (uploaded on the game's itch.io edit page)

| Image | Size (px) | Used for |
|---|---|---|
| Cover image | 630 × 500 | Required. The game's thumbnail in itch.io's browse pages, search and collections (the minimum is 315 × 250). Game art plus the logo; PNG, JPG or GIF. |
| Screenshots | 1280 × 800 | 3 to 5, taken in the game. They sit in a column beside the description. |
| Page banner | 960–1280 wide | Optional. Replaces the plain title at the top of the page; usually the logo on a transparent PNG. The page column is 960 px wide, wider with the game's 1280 embed. |
| Page background | any size | Optional. Art behind the page; keep it quiet so the text stays readable. |

## Music (optional)

An .ogg (or .mp3/.wav) at `audio/music/<track>.ogg` loops on its screens with a crossfade; missing tracks fall back to her theme, then `menu`. The Music slider shows in Settings once any track exists.

| Track | Plays on | In the game |
|---|---|---|
| `audio/music/menu.ogg` | Main menu, roster, gallery, store, credits. On its own it already covers the whole game. | Sweet Serene — Fablefly Music |
| `audio/music/succubus.ogg` | Amara's story: her conversations and chapters. | Sexy Scene Instrumentals Vol. 4 — Sascha Ende (CC BY 4.0) |
| `audio/music/mermaid.ogg` | Marina's story. | Underwater Theme II — Cleyton Kauffman (CC0) |
| `audio/music/slime.ogg` | Opal's story. | Binary Underwater Village — Alex McCulloch (CC0) |
| `audio/music/dryad.ogg` | Hazel's story. | Enchanted Hollow — Eric Matyas |
| `audio/music/night.ogg` | Every girl's night scene (otherwise her own theme plays). | Sexy Scene Vol. 3 — Sascha Ende (CC BY 4.0) |
| `audio/music/ending.ogg` | Every epilogue: its dialogue, story beats and final picture. | morning_2d (composer: fill in) |

## Already in the game

- Gems (10): `art/gems/ember.png`, `art/gems/moonstone.png`, `art/gems/petal.png`, `art/gems/pearl.png`, `art/gems/rune.png`, `art/gems/crystal.png`, `art/gems/cursed.png`, `art/gems/rocket_h.png`, `art/gems/rocket_v.png`, `art/gems/starburst.png`
- Item Shop icons (6): `art/store/moves.png`, `art/store/hammer.png`, `art/store/shuffle.png`, `art/store/colorBomb.png`, `art/store/favorCharm.png`, `art/store/heartMender.png`
- Marina: 7 waist-up expressions, `ending.png`, 60-frame idle swim loop, `art/backgrounds/mermaid_cove.png`
- Hazel: 7 waist-up expressions (`art/characters/dryad/<expression>.png`), `art/characters/dryad/main.png` (full figure on her tree), `art/characters/dryad/live/` (that figure as a live sprite: breathing, hair sway, blinking)

