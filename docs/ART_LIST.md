# Charm Combo — art list

Every image the game looks for. Put a PNG at its path (relative to the folder with `project.godot`) and the game uses it the next time the project is opened in Godot — no code changes. Missing files keep their placeholders. Status reflects what was in `art/` when this list was generated.

**102 to make · 28 already in the game · 5 optional extras · 19 store page images (Steam and itch.io).**

Character folders use the story ids: `succubus` (Amara), `mermaid` (Marina), `slime` (Opal), `dryad` (Hazel).

## Recommended order

1. Each girl's `neutral.png` — one file puts her on every screen.
2. The other six expressions per girl.
3. Backgrounds: library, woods, grove.
4. Logo + the ten small icons.
5. Story CGs (or first a `cg/warmth.png` + `cg/spark.png` per girl as stand-ins).
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
| `art/characters/succubus/cg/warmth_beat1.png` | Warm route — Story beat 1 (Caption under it in the game: “The reading room at dawn: a burnt-out candle in a smudged chalk circle, your jacket folded into a neat square on the returns cart.”) | Dawn light through tall library windows onto the reading room floor: the smudged chalk circle, a candle burnt down to a puddle of wax, your jacket folded into a perfect square on the returns cart. No people; the room tells it. | To make |
| `art/characters/succubus/cg/warmth_beat2.png` | Warm route — Story beat 2 (Caption under it in the game: “Her corrections in red pencil, all over the loose page that started it.”) | Close-up: the loose page with the summoning circle, covered in Amara's neat red-pencil corrections and arrows, one corner torn off where her name was; her clawed hand and the pencil at the edge of frame. | To make |
| `art/characters/succubus/cg/warmth_your_address.png` | Warm route — Final picture — “Forwarding Address” (Reached by replying “Put mine.”) | Your front room, now hers too: Amara kneeling at your bookshelf, reorganising it with grim satisfaction, candles on every surface, her library card propped on the mantel. You in the doorway, seen from behind. | To make |
| `art/characters/succubus/cg/warmth_reading_room.png` | Warm route — Final picture — “Night Shift” (Reached by replying “Put the reading room.”) | The dark reading room after closing: Amara with her feet up on the reading table, one candle lit beside a stack of annotated romance novels, looking up at you over a book with a small smile. | To make |
| `art/characters/succubus/cg/spark_beat1.png` | Spark route — Story beat 1 (Caption under it in the game: “The reading room couch in the morning: one coat, two people, a romance novel face down on the floor.”) | Morning on the reading room couch: Amara's coat thrown over two people (you only as a shoulder or an arm), her horns and tail just showing, a romance novel face down on the floor. Suggestive but covered; nothing explicit. | To make |
| `art/characters/succubus/cg/spark_beat2.png` | Spark route — Story beat 2 (Caption under it in the game: “A perfect circle in black ink, with your name where hers used to be.”) | Close-up: a perfect summoning circle in black ink on a ledger page, every ring closed, your name lettered in the gap where hers used to be. | To make |
| `art/characters/succubus/cg/spark_tonight.png` | Spark route — Final picture — “Correct Lines” (Reached by replying “Use it tonight.”) | Night, your floor: a flawless chalk circle with candles at its points and green smoke curling up; Amara stepping out of it towards you, entirely pleased with herself. | To make |
| `art/characters/succubus/cg/spark_make_wait.png` | Spark route — Final picture — “Overdue” (Reached by replying “Make me wait.”) | The library mid-shift, the door sign flipped to CLOSED EARLY; Amara leaning on the late desk with a pocket watch open, eyebrow raised at you. | To make |

Fallbacks: `art/characters/succubus/cg/warmth.png` and `cg/spark.png` cover every missing CG on that route.

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
| `art/characters/mermaid/cg/warmth_beat1.png` | Warm route — Story beat 1 (Caption under it in the game: “The boathouse slipway at sunrise, two sets of clothes drying on the rail.”) | Sunrise over the boathouse slipway: dark water, a heap of old sails, two sets of clothes hung to dry on the rail; Marina's tail fin breaking the water at the edge of frame. | To make |
| `art/characters/mermaid/cg/warmth_beat2.png` | Warm route — Story beat 2 (Caption under it in the game: “Gran at the Midsummer Tide, her pearl comb in her hair.”) | The Midsummer Tide at the cove: the whole family out on the rocks under a low summer moon, lanterns floating on the water, Gran in the middle with the nine-pearl comb in her hair, pretending not to notice everyone watching; Marina at the edge, eyes wet. | To make |
| `art/characters/mermaid/cg/warmth_she_tells.png` | Warm route — Final picture — “Family Table” (Reached by replying “You tell it.”) | Family dinner on the rocks by the cove: Marina mid-story with her arms flung wide, Gran rolling her eyes, her sisters laughing, a place set for you. | To make |
| `art/characters/mermaid/cg/warmth_you_tell.png` | Warm route — Final picture — “The Missing Shoe” (Reached by replying “I'll tell it. I'll leave out the shoe.”) | The boathouse wall: your lost shoe nailed up like a trophy with the date and "HERO" painted underneath, in quotation marks, Marina grinning beside it. | To make |
| `art/characters/mermaid/cg/spark_beat1.png` | Spark route — Story beat 1 (Caption under it in the game: “The boathouse floor at dawn: one fishing net, badly tangled, two people still inside it.”) | Dawn on the boathouse floor: a fishing net badly tangled round two people (Marina's tail, your arm), Marina laughing. Covered by the net and an old sail; nothing explicit. | To make |
| `art/characters/mermaid/cg/spark_beat2.png` | Spark route — Story beat 2 (Caption under it in the game: “Halfway to the rocks, one of you swimming a lot better than the other.”) | Morning sea: Marina towing you towards the rocks, very smug, you mid-splash and seen from behind. | To make |
| `art/characters/mermaid/cg/spark_lessons.png` | Spark route — Final picture — “Deep End” (Reached by replying “Lessons. I want to keep up with you.”) | Midsummer: you swimming to the rocks on your own, Marina circling underneath, one hand reaching up to pull you under. | To make |
| `art/characters/mermaid/cg/spark_rescue_me.png` | Spark route — Final picture — “Lifeguard Duty” (Reached by replying “Keep rescuing me.”) | The boathouse wall covered in tally marks, past a hundred, one labelled '63: puddle'; Marina adding another with a grin. | To make |

Fallbacks: `art/characters/mermaid/cg/warmth.png` and `cg/spark.png` cover every missing CG on that route.

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
| `art/characters/slime/cg/warmth_beat1.png` | Warm route — Story beat 1 (Caption under it in the game: “Morning light through the bedroom curtains, and someone translucent and lilac curled over the covers.”) | Your bedroom in morning light: Opal spread over the covers like a translucent lilac blanket, sunlight shining through her, a few treasures floating inside her; you as a shape under the covers. Cosy, not explicit. | To make |
| `art/characters/slime/cg/warmth_beat2.png` | Warm route — Story beat 2 (Caption under it in the game: “Opal at the baker's counter, a loaf under one arm and a stray button in her hand.”) | The bakery: Opal at the counter in her oversized cardigan, a loaf under one arm, proudly holding up a button she found; the baker leaning on the counter, patient. | To make |
| `art/characters/slime/cg/warmth_keep_jar.png` | Warm route — Final picture — “Storm Jar” (Reached by replying “Keep it. For storms.”) | Night, a thunderstorm at the window: Opal curled inside her old jar on the bedroom floor, you sitting beside it with a glass of wine, the two of you talking through the glass. | To make |
| `art/characters/slime/cg/warmth_collect_jar.png` | Warm route — Final picture — “Item Nought” (Reached by replying “Make it part of the collection.”) | The top of the collection shelf: the empty jar on display with a neat card in front, 'Lived here. Don't any more.' Opal admiring it. | To make |
| `art/characters/slime/cg/spark_beat1.png` | Spark route — Story beat 1 (Caption under it in the game: “The collection shelf at dawn, with one new item: a shirt, carefully folded, with a label.”) | Object shot: the collection shelf at dawn, buttons and keys in neat rows, and a folded, slightly torn shirt with a handwritten card: Item 442. | To make |
| `art/characters/slime/cg/spark_beat2.png` | Spark route — Story beat 2 (Caption under it in the game: “Quiz night at the Lamplighter: one terrible score, eleven recovered buttons.”) | The Lamplighter pub on quiz night: a scoresheet with a terrible score, Opal beaming over a little pile of eleven buttons she found under the tables. | To make |
| `art/characters/slime/cg/spark_on_purpose.png` | Spark route — Final picture — “A Collection of You” (Reached by replying “On purpose. Take whatever you like.”) | A whole shelf of your things, each with its own card (a scarf, a pen, a ticket, a note); Opal writing a new card, gone pink. | To make |
| `art/characters/slime/cg/spark_by_accident.png` | Spark route — Final picture — “Finders Keepers” (Reached by replying “By accident. It's more fun.”) | Opal sliding your cufflinks onto the third shelf while you search the room behind her, oblivious. | To make |

Fallbacks: `art/characters/slime/cg/warmth.png` and `cg/spark.png` cover every missing CG on that route.

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
| `art/characters/dryad/cg/warmth_beat1.png` | Warm route — Story beat 1 (Caption under it in the game: “The old hazel at dawn, in full blossom, in May.”) | The old hazel by the millrace at dawn, its east side covered in out-of-season blossom, petals scattered on the moss below over a blanket and a pair of boots. | To make |
| `art/characters/dryad/cg/warmth_beat2.png` | Warm route — Story beat 2 (Caption under it in the game: “A sapling beside the new millrace, a ribbon tied round it.”) | A young sapling beside the new millrace with a ribbon tied round it; Hazel's hand resting on its leaves. | To make |
| `art/characters/dryad/cg/warmth_hazel.png` | Warm route — Final picture — “Two Hazels” (Reached by replying “Another hazel. So you're not the only one.”) | Years on: a young hazel leaning towards the old one; Hazel on her branch, talking to it, holding your hand. | To make |
| `art/characters/dryad/cg/warmth_apple.png` | Warm route — Final picture — “The Spite Orchard” (Reached by replying “An apple tree. I want something to eat out here.”) | An absurdly loaded apple tree beside the old hazel; you eating an apple under Hazel's branches while the wasps veer away. | To make |
| `art/characters/dryad/cg/spark_beat1.png` | Spark route — Story beat 1 (Caption under it in the game: “Dawn under the old hazel: a root wrapped loosely round one ankle, entirely by accident.”) | Dawn under the hazel: a root looped gently round a bare ankle sticking out from a blanket on the moss; Hazel above, looking innocent. | To make |
| `art/characters/dryad/cg/spark_beat2.png` | Spark route — Story beat 2 (Caption under it in the game: “A branch hanging meaningfully over the footpath. Just in case.”) | The footpath past the grove: a branch hanging over it, poised; the miller's daughter walking underneath, unaware. | To make |
| `art/characters/dryad/cg/spark_keep_me.png` | Spark route — Final picture — “Taken Root” (Reached by replying “Keep me.”) | The old woodsman's hut at the edge of the grove at dusk, a twig landing on its roof; Hazel watching from her branch as you come up the path. | To make |
| `art/characters/dryad/cg/spark_catch_me.png` | Spark route — Final picture — “Patient Things” (Reached by replying “You'll have to catch me first.”) | The edge of the grove: you mid-stride, caught by a root round the ankle, Hazel looking very innocent. | To make |

Fallbacks: `art/characters/dryad/cg/warmth.png` and `cg/spark.png` cover every missing CG on that route.

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
| Icon — settings | `art/ui/settings.png` | The gear at the top right. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — play | `art/ui/play.png` | Main menu: Play. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — store | `art/ui/store.png` | Main menu: Store. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — gallery | `art/ui/gallery.png` | Main menu: Gallery. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — credits | `art/ui/credits.png` | Main menu: Credits. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — quit | `art/ui/quit.png` | Main menu: Quit. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |
| Icon — achievements | `art/ui/achievements.png` | Main menu: Achievements. 128 × 128 px, transparent PNG, simple bold shape. Shown at 16–26 px. | To make |

## Achievement icons (20)

Named after each achievement's Steam API name, in lowercase. Until an icon exists the game shows a plain medal.

| Achievement | Unlocks when | File | What to draw | Status |
|---|---|---|---|---|
| Welcome to Duskhaven | Get off on the wrong foot with someone. | `art/achievements/first_meeting.png` | Duskhaven's lantern-lit gate under a violet dusk sky. | To make |
| Opening Move | Clear your first chapter. | `art/achievements/first_chapter.png` | A single gem mid-sparkle, the first match. | To make |
| A Little Something | Give someone a gift. | `art/achievements/first_gift.png` | A small wrapped present with a ribbon bow. | To make |
| Thoughtful | Give all four gifts. | `art/achievements/all_gifts.png` | The four gifts together: beeswax candle, sea-glass pendant, glass marble, pocket sundial. | To make |
| Left the Candle Lit | Reach an ending with Amara. | `art/achievements/ending_amara.png` | A candle burning in the middle of a neatly drawn chalk circle (Amara's colors). | To make |
| High Tide | Reach an ending with Marina. | `art/achievements/ending_marina.png` | A nine-pearl comb on a cresting wave (Marina's colors). | To make |
| Out of the Jar | Reach an ending with Opal. | `art/achievements/ending_opal.png` | An open, empty jar with its lid off, one button beside it (Opal's colors). | To make |
| Putting Down Roots | Reach an ending with Hazel. | `art/achievements/ending_hazel.png` | A sapling with deep roots and one white blossom (Hazel's colors). | To make |
| The Whole Circle | Reach an ending with all four of them. | `art/achievements/all_four.png` | Four small motifs in a ring: candle, pearl comb, button, blossom. | To make |
| Two Sides of Her | See a warm and a spark ending with the same woman. | `art/achievements/both_routes.png` | A heart in two halves: one soft and glowing (warm), one crackling with a spark. | To make |
| Collector | Find 8 of the 16 endings. | `art/achievements/gallery_half.png` | A picture wall with half its little frames filled. | To make |
| Complete Gallery | Find all 16 endings. | `art/achievements/gallery_full.png` | A picture wall, every frame filled, edged in gold. | To make |
| Chain Reaction | Set off a x3 combo. | `art/achievements/combo_3.png` | Three gems chaining into each other with motion trails. | To make |
| Avalanche | Set off a x5 combo. | `art/achievements/combo_5.png` | A tumbling avalanche of gems. | To make |
| Starstruck | Make a Starburst. | `art/achievements/make_starburst.png` | The Starburst gem, glowing (match the in-game gem). | To make |
| Mega Blast | Swap two special gems together. | `art/achievements/mega_blast.png` | Two special gems colliding in a burst of light. | To make |
| Irresistible | Fill the Charm ring for a Charm Burst. | `art/achievements/charm_burst.png` | The Charm ring fully lit around its heart. | To make |
| With Moves to Spare | Clear a chapter with 5 or more moves left. | `art/achievements/moves_left_5.png` | An hourglass with plenty of sand still at the top. | To make |
| Shard Smasher | Clear a cursed shard with the Hammer. | `art/achievements/shard_smash.png` | A small hammer cracking a dark cursed shard. | To make |
| Window Shopping | Buy something in the Item Shop. | `art/achievements/first_purchase.png` | A little shop bag with a star-shaped tag. | To make |

## Launch

| Asset | File | Notes | Status |
|---|---|---|---|
| App icon | `icon.svg (replace)` | The same mark as the logo, readable at 16 px. 1024 × 1024 PNG or SVG master. Used for the game window and taskbar while it runs. | To make |
| Windows .exe icon | `icon.ico` | Made from the app icon. One .ico with 16, 24, 32, 48, 64, 128 and 256 px sizes. Needs the rcedit tool set up in Godot's Editor Settings to be written into the exe. | To make |

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

| Track | Plays on |
|---|---|
| `audio/music/menu.ogg` | Main menu, roster, gallery, store, credits. On its own it already covers the whole game. |
| `audio/music/succubus.ogg` | Amara's story: her conversations and chapters. |
| `audio/music/mermaid.ogg` | Marina's story. |
| `audio/music/slime.ogg` | Opal's story. |
| `audio/music/dryad.ogg` | Hazel's story. |
| `audio/music/night.ogg` | Every girl's night scene (otherwise her own theme plays). |
| `audio/music/ending.ogg` | Every epilogue: its dialogue, story beats and final picture. |

## Already in the game

- Gems (10): `art/gems/ember.png`, `art/gems/moonstone.png`, `art/gems/petal.png`, `art/gems/pearl.png`, `art/gems/rune.png`, `art/gems/crystal.png`, `art/gems/cursed.png`, `art/gems/rocket_h.png`, `art/gems/rocket_v.png`, `art/gems/starburst.png`
- Item Shop icons (6): `art/store/moves.png`, `art/store/hammer.png`, `art/store/shuffle.png`, `art/store/colorBomb.png`, `art/store/favorCharm.png`, `art/store/heartMender.png`
- Marina: 7 waist-up expressions, `ending.png`, 60-frame idle swim loop, `art/backgrounds/mermaid_cove.png`
- Hazel: 7 waist-up expressions (`art/characters/dryad/<expression>.png`), `art/characters/dryad/main.png` (full figure on her tree), `art/characters/dryad/live/` (that figure as a live sprite: breathing, hair sway, blinking)

