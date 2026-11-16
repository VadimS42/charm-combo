# Android

The **Android** export preset makes an APK (or, later, an AAB for Google
Play) with the safe-for-work story (`docs/SFW_CONTENT.md`). Package name:
`com.charmcombo.game`; change it in the preset before your first upload,
because it can never change after that.

## What the game does on phones and tablets

- **Screen:** portrait and landscape; the game follows the phone as it turns (round 47). Everything stays inside the display's safe area (camera notch, rounded corners).
- **Its own interface (round 47):** phone-sized text and buttons, and menus as a tab bar (Home, Girls, Shop, Gallery, More) with big cards. Chapters and dialogue are laid out for whichever way the phone is held (`scripts/mobile/MobileShell.gd`, `PuzzleScreen._build_ui_mobile()`). Try it on PC with `-- --mobile` and a tall or wide window.
- **Swapping:** tap a gem then its neighbour, or swipe a gem towards it.
- **Back button / gesture:** works like B. It closes a dialog, closes Settings or goes back a screen; on the main menu it leaves the game.
- **Desktop-only parts hidden:** the Quit button, Fullscreen and "Open log folder".
- **Saves:** the game saves when it's sent to the background.
- **Rendering:** uses the Compatibility renderer, so it runs on older devices too (Android 5.0+, ARM 32- and 64-bit).

## Building it yourself

1. In the Godot editor: Editor → Manage Export Templates → Download (they include Android).
2. Install the Android SDK, either through Android Studio or the command-line tools with `platform-tools`, `build-tools;34.0.0` and `platforms;android-34`. You also need JDK 17 or newer.
3. Editor → Editor Settings → Export → Android:
   - **Android SDK Path:** your SDK folder.
   - **Java SDK Path:** your JDK folder.
   - **Debug keystore:** Godot makes one, or use `keytool` (user `androiddebugkey`, password `android`).
4. Run `python3 tools/make_sfw_data.py`.
5. Project → Export → **Android** → Export Project. "Export With Debug" makes a test APK.
6. Install it on a phone with USB debugging on: `adb install CharmCombo-debug.apk`. Or copy the APK to the phone and open it.

## For Google Play

- **Release keystore:** make your own and keep it safe; losing it means you can't update the app. Set it in the preset (Keystore → Release).
- **App bundle:** Google Play wants an AAB. Tick Gradle Build in the preset (Project → Install Android Build Template first) and set Export Format to AAB.
- **Target SDK:** Play needs a recent one (34 or newer as of 2026). Godot 4.3's default is 34.
- **Content rating:** fill in the content questionnaire honestly (romance, suggestive outfits).

## Not done yet (next steps for the port)

- **Finishing the mobile interface:** the ending screens, the age gate and the language picker still use the desktop layout, made to fit; they work but aren't redesigned yet. Her full sprite in chapters is just her face in a frame on phones.
- **Touch extras:** long-press for tooltips (hover text doesn't exist on touch screens) and vibration on matches.
- **Store integration:** Google Play Games achievements and in-app purchases, if wanted.
