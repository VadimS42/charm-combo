# Google Play: the free, ad-supported build

There are two Android builds (round 50):

| Export preset | Where | What's in it |
| --- | --- | --- |
| **Android (itch.io)** | itch.io, paid | The safe-for-work story, no ads, no purchases, normal difficulty. Unchanged. |
| **Android (Google Play)** | Google Play, free | The same story, plus ads, in-app purchases, hearts and the hardest tuning. Export feature `ads`. |
| **Android (Google Play preview)** | your own phone | The Google Play build with pretend ads and purchases (no money, no AdMob account), to try the whole flow. |

Everything lives in `autoload/Monetize.gd` (rules, providers, saving) and
`scripts/monetize/` (`ShopUI.gd`: the popups and shop; `AdMobBridge.gd`: AdMob).
Nothing in it runs on Steam, Epic, itch.io or the itch.io Android build.
Try it on a PC: `godot --path . -- --ads` (phone layout, test ads and purchases).

## What the Google Play build does

**Harder:** chapters 2–4 give 80% of their moves (`MOVES_FACTOR`; each girl's
first chapter keeps all of them, so players get hooked first), the Item Shop's
star prices are 1.5x (`PRICE_FACTOR`), and Story difficulty, the Skip button and
"Continue the story" after three losses come only with the Story Pass.

**Hearts:** 5 (8 with the Story Pass). Losing a chapter costs one; one comes
back every 25 minutes. With none left, a chapter won't start: the Out of hearts
popup offers a video (+1), a refill for 60 stars, 24 hours unlimited, or the
Story Pass. The hearts pill sits next to the stars at the top.

**Reward videos** (each has a daily limit, `DAILY_CAPS`):
- Out of moves: +5 moves (6 a day)
- Chapter cleared: double its stars (6 a day)
- Shop: +15 free stars (5 a day)
- Out of hearts: +1 heart (5 a day)
- Daily challenge: one more try (1 a day)

**Ads between chapters:** never in the first 3 chapter ends, then at most every
2nd chapter end and at least 2.5 minutes apart (`GRACE`, `EVERY`,
`INTERSTITIAL_GAP`). They never play during the story itself.

**Banner:** along the bottom of the phone menus (Home, Girls, Shop, Gallery,
More), with room left for it. Never on a chapter or in the story.

**In-app purchases** (Shop tab, and Remove ads under More):

| Product ID | Type | Name | Suggested price | Gives |
| --- | --- | --- | --- | --- |
| `starter_pack` | one-time | Starter Pack | $1.99 | 500 stars, 3 of every item, 24 h unlimited hearts |
| `remove_ads` | one-time | No Ads | $3.99 | no banner or between-chapter ads; reward videos become one tap |
| `story_pass` | one-time | Story Pass | $4.99 | skip any chapter, Story difficulty, 8 hearts |
| `hearts_24h` | consumable | Unlimited Hearts | $1.99 | 24 h unlimited hearts |
| `item_bundle` | consumable | Item Bundle | $2.99 | 5 of every item |
| `stars_150` | consumable | Handful of Stars | $0.99 | 150 stars |
| `stars_800` | consumable | Pouch of Stars | $4.99 | 800 stars |
| `stars_1800` | consumable | Chest of Stars | $9.99 | 1,800 stars |
| `stars_5000` | consumable | Treasury of Stars | $24.99 | 5,000 stars |

Prices in the game come from Google Play (in the player's currency) once it
answers; the ones above only show until then. Purchases are kept apart from
story progress, so *Reset progress* never removes them, and *Restore purchases*
(More) brings them back on a new phone. To change any number or product, edit
the constants at the top of `Monetize.gd`.

Left out on purpose: loot boxes and random paid rewards (several countries
treat them as gambling, and Google requires published odds), and subscriptions
(they need a server to check renewals properly).

## Setting it up

### 1. Google Play Console
1. Create the app (Free). **Target audience: 13+** (or 16+/18+). If you pick
   ages under 13, Google's Families policy applies: only certified ad networks,
   no personalised ads, and stricter review. The romance theme fits 13+ at the
   lowest. The content rating questionnaire will say it has ads and purchases.
2. **Monetize > Products > In-app products:** create each product ID in the
   table above (exactly as written), with a name, description and price, and
   activate it.
3. **Data safety:** declare that the app uses AdMob (advertising ID, app
   interactions, diagnostics) and Google Play Billing (purchase history).
4. **License testing** (Setup > License testing): add your Google account,
   so test purchases cost nothing.

### 2. AdMob
1. Create an AdMob account and add the app (Android). Note the **App ID**
   (`ca-app-pub-…~…`).
2. Create three ad units: **Rewarded**, **Interstitial**, **Banner**.
3. Put the three ad unit IDs in `AD_UNITS` at the top of `autoload/Monetize.gd`.
   The ones there now are Google's public test units: they show test ads and
   pay nothing.
4. **Privacy & messaging:** create a GDPR consent message (and US states
   message). The game shows it on first launch (`AdMobBridge.gd`), and players
   can change their answer from More > Ad privacy choices.

### 3. The plugins (in the Godot editor)
1. **AdMob:** Poing Studios' *Godot AdMob* plugin. On Godot 4.3, use a **3.x**
   release. The 4.x releases need Godot 4.5+, and `AdMobBridge.gd` works with
   either. Copy it into `addons/admob/`, enable it in Project Settings >
   Plugins, then set **AdMob > General > Android > Enabled** and your **App ID**
   in Project Settings.
2. **Google Play Billing:** the *GodotGooglePlayBilling* plugin (latest
   release, for Godot 4.2+). Copy it into `addons/GodotGooglePlayBilling/` and
   enable it in Project Settings > Plugins.
3. **Project > Install Android Build Template.**
4. In the **Android (Google Play)** preset: Gradle build is already on; set
   **Min SDK 24** (AdMob needs it) and **Target SDK** to what Google Play
   currently requires (Play Console says when you upload), and the release
   keystore.

The game finds the plugins by itself. In the Output on a phone,
`Monetize: ads admob, billing play` means both are working.

### 4. Build and test
- **Export > Android (Google Play)** writes `build/android/CharmCombo-play.aab`
  (an app bundle, what Play wants). Upload it to an **internal testing** track
  and install it from the Play Store link on your phone: billing only works
  for apps installed from Play.
- With the test ad units still in `AD_UNITS`, you'll see Google's test ads.
  Never tap your own real ads; AdMob can close your account for it.
- **Android (Google Play preview)** needs none of the above: it's a normal APK
  with the game's own pretend ads (a 3-second "Test rewarded video" screen)
  and pretend purchases ("Test purchase … no money changes hands"). It installs
  next to the real one (its own package name).

## Tests
- `godot --headless --path . -s tools/monetize_test.gd -- --ads` checks hearts,
  videos and their limits, ad pacing, every purchase, No Ads, the Story Pass,
  and that purchases survive a reset and a reload.
- `smoke_test.gd`, `mechanics_test.gd` and `pad_test.gd` also run with `-- --ads`.
- `balance_bot.gd -- mode=girls girl=all scale=0.8` plays the chapters on the
  Google Play build's moves. The casual bot (no power-ups) clears chapters 2–4
  24–55% of the time there, against 56–84% normally; first chapters stay ~90%.
