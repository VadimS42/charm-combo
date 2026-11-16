# Epic Games Store

The **Windows (Epic)** export preset makes the Epic build: one `.exe`, the
safe-for-work version of the story (`docs/SFW_CONTENT.md`), and no Steam
anywhere.

## What the game already does for Epic

- **No Steam:** GodotSteam is left out of the package, and there's no "Wishlist on Steam" button and no "unlocks on Steam too". Epic doesn't allow links to other stores.
- **Launcher arguments:** the Epic launcher starts the game with arguments like `-AUTH_PASSWORD=…`, `-epicapp=…` and `-epiclocale=…`. Godot ignores them, so the game starts normally. `Platform.store_locale()` reads `-epiclocale` if you want to use it.
- **Saves:** they live in the user's AppData (`CharmCombo` folder). For Epic cloud saves, point the Epic dev portal's cloud save settings at that folder.
- **Achievements:** they always work in the game. Sending them to Epic needs Epic Online Services (EOS), which plugs in through one small script (below).

## Exporting

1. Run `python3 tools/make_sfw_data.py`.
2. Project → Export → **Windows (Epic)**, or from the command line:
   ```
   godot --headless --path . --export-release "Windows (Epic)" build/epic/windows/CharmCombo.exe
   ```
3. Upload the `build/epic/windows/` folder with Epic's BuildPatchTool. Set the launch executable to `CharmCombo.exe`.

## Epic achievements (optional): the EOS bridge

1. Create the product in the Epic Developer Portal. Add the achievements there, using the same ids as `autoload/Achievements.gd` (e.g. `HAZEL_MEET`, `COMBO_3`). The icons are in `steam/achievements/`.
2. Install an EOS plug-in for Godot 4, for example "EOSG" (Epic Online Services Godot) from the Godot Asset Library or GitHub.
3. Add `addons/epic/epic_bridge.gd`. The game loads it only in Epic builds, and only if it exists:
   ```gdscript
   extends Node
   # Called once at startup with the launcher's arguments.
   func start(args: PackedStringArray) -> void:
       # Initialise EOS with your product / sandbox / deployment ids and
       # log in with the exchange code from -AUTH_PASSWORD=<code>
       # (auth type "exchangecode"). See your EOS plug-in's samples.
       pass
   # Called every time an achievement unlocks (and for earlier ones).
   func unlock_achievement(id: String) -> void:
       # Ask EOS to unlock achievement `id` for the logged-in user.
       pass
   ```
   Fill in the two functions from your plug-in's own samples. Nothing else in the game needs changing (`Platform._start_epic()`, `Platform.set_achievement()`).

## Store page

Epic rates games through IARC during submission. The safe-for-work build still has suggestive outfits and romance, so expect roughly a Teen–Mature rating. `docs/STORE_PAGE.md` has text to adapt: leave out the adult lines for Epic.
