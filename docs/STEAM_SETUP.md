# Steam setup — Charm Combo

Everything on the game's side is already built. What's left happens on
Steam's website (Steamworks) and takes an App ID, which you get by paying
Steam's $100 fee for the game (you get it back once the game has made $1,000
on Steam). This guide walks through it in order.

## What the game already does

- **20 achievements**, earned in any build. The Steam build also unlocks them
  on Steam (Steam's own pop-up replaces the game's), including any earned
  before Steam was connected. The list is in `autoload/Achievements.gd`, and
  the table in step 3 is what to type into Steamworks.
- **Rich presence**: Steam friends see what you're up to, like "Chapter 2 of
  Marina's story" or "Wandering Duskhaven" (`steam/rich_presence_english.vdf`).
- **Cloud saves**: ready. It's a Steamworks setting, no code (step 5).
- **Steam overlay**: works as soon as the plug-in is installed (step 2). The
  game also saves when the overlay opens.
- **Controller and Steam Deck**: full controller play (menus, puzzles, story,
  items), with button prompts that switch between keyboard and pad. The game's
  screen is 1280x800, exactly the Deck's.
- **A separate Steam build**: the "Windows (Steam)" export preset. The itch.io
  presets never touch Steam.

Nothing Steam-related runs until steps 1 and 2 are done. Until then the game
behaves exactly like the itch.io builds.

## 1. Get your App ID and put it in the game

1. Sign up at [partner.steamgames.com](https://partner.steamgames.com), pay the
   Steam Direct fee, and create the app. Steamworks shows its **App ID** (a
   number such as 3456780).
2. In Godot, open `autoload/Platform.gd` and change

   ```gdscript
   const STEAM_APP_ID := 0
   ```

   to your number. That's the only place it goes.

## 2. Install GodotSteam (the Steam plug-in)

Godot doesn't talk to Steam on its own; the free GodotSteam plug-in does. I
couldn't download it for you (the site that hosts it is blocked from where I
work), but it's a two-minute install:

1. In Godot, open the **AssetLib** tab at the top of the editor.
2. Search for **GodotSteam**, and pick **"GodotSteam GDExtension 4.1 - 4.3"**
   (version 4.15). The game uses Godot 4.3, and the newer GodotSteam releases
   are for Godot 4.4 and up. It's marked "Deprecated" only because it's the
   last version for 4.3; that's expected.
3. Click **Download**, then **Install**. It goes into `addons/godotsteam/`.
4. Restart Godot (Project > Reload Current Project).

If AssetLib can't find it, the direct download is
`https://codeberg.org/godotsteam/godotsteam/releases/download/v4.15-gde/godotsteam-4.15-gdextension-plugin-4.1-4.3.zip`.
Unzip it and copy its `addons` folder into the project folder, next to
`project.godot`.

**Check that it works:** open the Steam app on your PC, then run the game from
Godot. The Output panel at the bottom should show
`Platform: Steam connected`, and **Shift+Tab** should open the Steam overlay
in the game window.

- **No App ID yet?** You can still test the plug-in with 480, Valve's public
  test app ("Spacewar"): set `STEAM_APP_ID := 480`, run the game, and check
  the overlay opens. Change it back to 0 afterwards. Your achievements won't
  show up under Spacewar; that's normal.
- If the Output says `Steam not available`, the Steam app isn't running, or
  the App ID isn't set.

## 3. Add the achievements in Steamworks

In Steamworks: your app > **Edit Steamworks Settings** > **Stats &
Achievements** > **Achievements**. Click **New Achievement** for each row
below and copy the **API name** exactly (capitals and underscores included:
it's how the game finds each one). Leave "Set By" on **Client**. None of them
need to be hidden.

| API name | Name | Description |
| --- | --- | --- |
| FIRST_MEETING | Welcome to Duskhaven | Get off on the wrong foot with someone. |
| FIRST_CHAPTER | Opening Move | Clear your first chapter. |
| FIRST_GIFT | A Little Something | Give someone a gift. |
| ALL_GIFTS | Thoughtful | Give all four gifts. |
| ENDING_AMARA | Left the Candle Lit | Reach an ending with Amara. |
| ENDING_MARINA | High Tide | Reach an ending with Marina. |
| ENDING_OPAL | Out of the Jar | Reach an ending with Opal. |
| ENDING_HAZEL | Putting Down Roots | Reach an ending with Hazel. |
| ALL_FOUR | The Whole Circle | Reach an ending with all four of them. |
| BOTH_ROUTES | Two Sides of Her | See a warm and a spark ending with the same woman. |
| GALLERY_HALF | Collector | Find 8 of the 16 endings. |
| GALLERY_FULL | Complete Gallery | Find all 16 endings. |
| COMBO_3 | Chain Reaction | Set off a x3 combo. |
| COMBO_5 | Avalanche | Set off a x5 combo. |
| MAKE_STARBURST | Starstruck | Make a Starburst. |
| MEGA_BLAST | Mega Blast | Swap two special gems together. |
| CHARM_BURST | Irresistible | Fill the Charm ring for a Charm Burst. |
| MOVES_LEFT_5 | With Moves to Spare | Clear a chapter with 5 or more moves left. |
| SHARD_SMASH | Shard Smasher | Clear a cursed shard with the Hammer. |
| FIRST_PURCHASE | Window Shopping | Buy something in the Item Shop. |

**Icons.** Steam wants two per achievement, 256x256 PNG or JPG: an "achieved"
one and an "unachieved" (usually grey) one. You only need to draw the achieved
ones: save them as `art/achievements/<api name in lowercase>.png` (for
example `art/achievements/first_meeting.png`) and the game's Achievements
screen uses them right away. Then open `tools/make_steam_achievement_icons.gd`
in Godot's Script editor and choose **File > Run**: it writes both versions
of every icon, at 256x256, to `steam/achievement_icons/`, ready to upload.

When all 20 are in, go to the **Publish** tab and publish. Achievement
changes don't reach the game until they're published.

**Changing or adding achievements later:** edit the list in
`autoload/Achievements.gd` and add the same API name in Steamworks. Steam
allows 100 achievements for a new game.

**Testing tip:** while Testing Mode is on, the game doesn't tell Steam about
new achievements. They're still saved in the game, though, and get sent the
next time the Steam build runs with Testing Mode off. To wipe your own
account's achievements after testing, paste `steam://open/console` into your
browser's address bar (it opens Steam's console) and type
`reset_all_stats <your App ID>`. Players never see Testing Mode once
`ALLOW_TESTING_MODE` is off (see "Before you release").

## 4. Rich presence (what friends see)

In Steamworks: **Edit Steamworks Settings** > **Community** > **Rich
Presence**, upload `steam/rich_presence_english.vdf`, then publish. You can
change the wording in that file (keep the `#Status_...` names and the
`%girl%` / `%chapter%` parts as they are) and re-upload. Valve's tester at
[steamcommunity.com/dev/testrichpresence](https://steamcommunity.com/dev/testrichpresence)
shows what your friends would see while you play.

## 5. Cloud saves (Steam Auto-Cloud)

No code needed: Steam copies the save files for you. In Steamworks: **Edit
Steamworks Settings** > **Application** > **Steam Cloud**:

1. **Byte quota per user:** `1000000` (1 MB; a save is only a few KB).
   **Number of files allowed per user:** `10`.
2. Under **Root Paths**, add one:
   - Root: **WinAppDataRoaming**
   - Subdirectory: `CharmCombo`
   - Pattern: `save*.json` (that's `save.json` and its backup)
   - Recursive: off
3. Save, and publish.

This also covers the Steam Deck, which runs the Windows build through Proton.
If you add a native Linux or Mac build later, add root overrides for Linux
(**LinuxXdgDataHome**, same `CharmCombo` folder) and Mac (**MacAppSupport**,
same folder), which is where the game keeps its save on those systems.

## 6. Export the Steam build

1. In Godot: **Project > Export**, select **Windows (Steam)**.
2. Click **Export Project**, keep the path `build/steam/windows/CharmCombo.exe`,
   and **untick "Export With Debug"**.
3. With GodotSteam installed, the export puts `steam_api64.dll` and the
   plug-in's own DLL next to the exe. Upload the whole folder, not just the exe.

**Testing the exported exe by double-clicking it:** once `STEAM_APP_ID` is set,
the exe asks Steam to relaunch it from your library. To test it straight from
the folder instead, create a text file called `steam_appid.txt` next to
`CharmCombo.exe` containing only your App ID. The upload script leaves that
file out.

## 7. Set up the depot (once)

In Steamworks: your app > **SteamPipe** > **Depots**. Steam already made one
depot, usually numbered App ID + 1. Set it to **Windows**, and publish.
Under **Installation** > **General Installation**, add a launch option:
executable `CharmCombo.exe`, operating system Windows.

## 8. Upload the build

1. Download the **Steamworks SDK** from the Steamworks site (it's linked from
   the Steamworks home page and the documentation), and unzip it somewhere like
   `C:\steamworks_sdk`.
2. Open `steam/app_build.vdf` in a text editor and replace `YOUR_APP_ID` and
   `YOUR_DEPOT_ID` with your numbers.
3. Open `steam/upload_to_steam.bat` in a text editor and fill in the two lines
   at the top: where `steamcmd.exe` is (in the SDK:
   `tools\ContentBuilder\builder\steamcmd.exe`) and your Steam account name.
4. Double-click `upload_to_steam.bat`. It asks for your password and a Steam
   Guard code the first time. It uploads `build/steam/windows/`.
5. In Steamworks > **SteamPipe** > **Builds**, set the new build live on the
   **default** branch (or a beta branch first, to test it through Steam).

## 9. Steam Deck and controllers

The game is ready for Steam Deck: controller play everywhere, button prompts
that say A / B / X / Y (matching the Deck), no typing, no launcher, and the
screen is exactly the Deck's 1280x800. The smallest text is 10px, above
Valve's 9px minimum for the Deck (the tiny "placeholder" labels are smaller,
but they disappear as the real art goes in).

In Steamworks' **Steam Input** settings, choose the **Gamepad** template as
the default for Xbox, PlayStation and Switch controllers and the Steam Deck.
When the store page asks about controller support, it's **full controller
support**; the game doesn't use the Steam Input API.

**In-game controls with a pad:** D-pad or left stick moves, **A** picks up and
swaps gems or presses buttons, **B** goes back, **Start** opens Settings,
**RB** / **X** / **Y** use the +3 Moves / Hammer / Shuffle items, and the
right stick scrolls long screens. Keyboard: arrows, Enter, Backspace, Esc, and
1 / 2 / 3 for the items.

## 10. The store page

Store art sizes are all in `docs/ART_LIST.md` (the "Launch" section, also
on the art list page), and `docs/STORE_PAGE.md` has starter text for the
description. Steam reviews
the store page (3 to 5 business days) and the build before release, and the
page has to show as "Coming Soon" for at least 2 weeks before you can
release. Submit the page early.

The game is 18+: fill in the **Mature Content** part of the content survey
honestly. `docs/STORE_PAGE.md` ("Content questions") lists what's in the game
and suggests wording. **Adult content:** adding explicit lines to the night
scenes, or explicit CGs, moves the game into "Adult Only Sexual Content", which
changes who can see it on Steam and puts it under Steam's payment-processor
rule; read that section before you do.

## Before you release

- `autoload/GameState.gd`: set `ALLOW_TESTING_MODE := false`.
- Fill in `data/credits.txt`.
- Export with **"Export With Debug" unticked**.
- Leave `RESTART_THROUGH_STEAM` on in `autoload/Platform.gd`, so the game
  always runs through Steam (that's what makes achievements and the overlay
  work for players).

## Later, if you want

- **Leaderboards** (for example best score per chapter) and **stats** can be
  added the same way the achievements were. Ask and I'll wire them up.
- **Trading cards** are switched on by Valve once the game qualifies. They
  need their own art (cards, profile backgrounds, emoticons, badges).
- A **native Linux or Mac Steam build**: duplicate the itch.io preset, change
  its feature tag from `itch` to `steam`, and remove `addons/godotsteam/*` from
  its exclude list. The Windows build already covers the Deck through Proton.
