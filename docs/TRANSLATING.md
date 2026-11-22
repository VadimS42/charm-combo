# Translating Charm Combo

The game has 13 languages: English, Simplified Chinese (`zh_CN`), Hindi (`hi`),
Spanish (`es`), Arabic (`ar`), French (`fr`), Bengali (`bn`), Brazilian
Portuguese (`pt_BR`), Russian (`ru`), Indonesian (`id`), Japanese (`ja`), German
(`de`) and Ukrainian (`uk`). That's the ten most spoken languages in the world
(by total speakers), plus Japanese, German and Ukrainian. Urdu is next on that
list if you want another. Players
pick a language on first launch, and can change it in Settings. Voices stay in
English; only the text changes. Anything without a translation shows in English.

## The round trip

1. **Export** (only needed after the English text changes):
   `python3 tools/i18n/make_txt.py` writes `translations/txt/en/`:
   `dialogue_amara.txt`, `dialogue_marina.txt`, `dialogue_opal.txt`,
   `dialogue_hazel.txt` (each about 1,850 words) and `interface.txt` (menus,
   buttons, tips, achievements: about 1,400 words), plus `translations/keys.json`.
2. **Translate** each file (a translator, or a chat with Claude). The files
   explain themselves at the top: translate the text under each `@@ key` line,
   keep the `@@` lines, `%d` and `%s` as they are. Paste a file whole, ask for it
   back whole.
3. **Import**: save the translated files anywhere, then
   `python3 tools/i18n/import_txt.py ru <files...>` (or any locale code
   above). It merges them into `translations/<locale>.po`, keeps what's already
   there, and lists anything it skipped (an unknown `@@` key, or a line whose
   `%d` / `%s` don't match the English).
4. Open the project in Godot (or rebuild): that's it.

## How it works

Godot translates every label and button by its exact English text, using the
`.po` files listed in `project.godot` (`internationalization/locale/translations`).
Text built from pieces in code goes through `UITheme.t()` first (for example
`UITheme.t("Chapter %d / %d") % [a, b]`), so its pattern is what gets translated.
If you change an English line in `data/characters.json`, its old translation no
longer matches: export, translate the changed lines, import.

Chinese uses the bundled `assets/fonts/CharmComboCJK.otf`, a subset of Noto Sans
CJK SC covering the 7,000-odd GB2312 characters (rare characters outside it fall
back to the system font on Windows).

Japanese uses the bundled `assets/fonts/CharmComboJP.otf` (a subset of Noto Sans
JP). When the language is Japanese the game puts it ahead of the Chinese font,
so shared characters get Japanese glyph shapes; in Chinese it's the other way
round (`UITheme.install_fonts()`).

Hindi, Arabic and Bengali use bundled Noto Sans fonts
(`CharmComboDevanagari.ttf`, `CharmComboArabic.ttf`, `CharmComboBengali.ttf`;
licences in `data/font_licenses.txt`). Godot shapes them itself (joined Arabic
letters, Indic conjuncts), so nothing depends on the player's system fonts.

**Arabic is right-to-left.** Godot mirrors the whole layout when the language is
Arabic: back buttons go on the right, rows read right to left. Two things are
kept the other way on purpose: the puzzle board (a grid of gems has no reading
direction, and swaps must match the D-pad), and the D-pad in Settings' choice
rows swaps left and right so it follows what you see. In the Arabic text, arrows
point the RTL way: "→" for back and "◂" instead of "▸".

## Checking a translation

`python3 tools/i18n/qc.py` (or `qc.py fr uk` for some) checks every language
against the English: nothing missing, `%d` / `%s` kept, the numbers kept (150,
2000…), the symbols kept (⭐ ▸ ←), the girls' names present wherever the English
names them, each item called the same thing everywhere, no leftover English in
non-Latin scripts, no short label that grew far too long for its button, and no
hedged gender forms ("(-ла)", "(a)"): **the player character is a man**, so his
lines use masculine forms. Problems make it exit with 1; notes are things to
look at by eye (a long label, a number written as a word).

## Machine drafts: please get them checked

Japanese, Spanish, Brazilian Portuguese and German (round 49), and Hindi, Arabic,
French, Bengali, Indonesian and Ukrainian (round 52) are **drafts made with
Claude, not by native speakers.** They are complete (every line, the
interface and all four stories) and keep the girls' voices, but a native
speaker should read them before release, the story files especially. The
translator's copy is `translations/txt/<locale>/`: edit those files, then
import them again (step 3 above). Names stay in English letters in Spanish,
Portuguese and German; Japanese uses アマラ・ダスクローズ, マリーナ・ウェイヴァリー,
オパール, ヘイゼル・モスグローヴ and ミルブルック.

Round 52 names: French and Indonesian keep the English letters. Hindi: अमारा
डस्करोज़, मरीना वेवर्ली, ओपल, हेज़ल मॉसग्रोव, मिलब्रुक. Arabic: أمارا داسكروز,
مارينا ويفرلي, أوبال, هيزل موسغروف, ميلبروك. Bengali: আমারা ডাস্করোজ, মেরিনা
ওয়েভারলি, ওপাল, হেজেল মসগ্রোভ, মিলব্রুক. Ukrainian: Амара Даскроуз, Марина
Вейверлі, Опал, Гейзел Мосґроув, Міллбрук.
