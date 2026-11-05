# Translating Charm Combo

The game has English, Simplified Chinese (`zh_CN`) and Russian (`ru`). Players
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
   `python3 tools/i18n/import_txt.py ru <files...>` (or `zh_CN`). It merges them
   into `translations/ru.po` / `translations/zh_CN.po`, keeps what's already
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
