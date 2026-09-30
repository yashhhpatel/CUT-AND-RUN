# Slice & Run: Cut Master

A 2D portrait runner for Android built with Flutter. Run → collect → **cut** → split → avoid → choose → combine → escape → reward.

## Gameplay
- **Drag** in the bottom area to steer. **Swipe** anywhere above the runner to slice objects.
- Cuts really split objects into polygon pieces. Small pieces are collectible shards; big pieces are still obstacles, so *where* you cut matters.
- Materials: soft (wood, melon, rope, jelly), medium (crystal, prism: swipe fast), hard (metal: two hits), reinforced (steel: cut the seam), uncuttable (obsidian).
- Specials: energy cells (Cut Chain), mystery boxes, relics (collect them whole), glass membranes.
- Gates (add, multiply, subtract, quantity, sacrifice, fusion, material, relic, risk, reward, power-up), risk/reward lanes, 13 hazard types, 10 power-ups, combos and "Perfect" actions.
- 1000 generated campaign levels across 10 worlds, Daily Challenge with streaks, Endless mode, achievements, cosmetics.

## Project layout
```
lib/core        theme, config, geometry
lib/game        simulation (engine, entities, systems, effects, render). Pure Dart, no widgets
lib/levels      LevelConfig, reusable segments, campaign/daily/endless generators, worlds
lib/progression progress store, achievements, cosmetics
lib/services    storage, settings, audio, haptics, ads (AdMob), purchases (Remove Ads)
lib/screens     home, level map, gameplay (HUD/overlays), daily, endless, skins, achievements, settings
tool/           icon + audio generators (all assets are original and procedurally made)
```

## Build
Requires Flutter 3.22+ and JDK 17.

```bash
flutter pub get
flutter test
tool/build_android.sh release
```

`flutter build apk` works too, unless the project path contains `&`. In that case use the script, which calls Gradle directly.

### Production configuration
No real IDs are committed. For release, pass:
- `--dart-define=ADMOB_INTERSTITIAL_ID=...`, `--dart-define=ADMOB_REWARDED_ID=...`
- `-PadmobAppId=ca-app-pub-...~...` (or `ADMOB_APP_ID` in `android/local.properties`)
- Google Play Billing products (create in Play Console):
  - Subscription `remove_ads_monthly`: 1 Month Ads-Free, monthly auto-renewing base plan, ₹299
  - In-app product `remove_ads_lifetime`: Lifetime Ads-Free, one-time, ₹2,999
  - Override IDs with `--dart-define=ADS_FREE_MONTHLY_ID=...` / `ADS_FREE_LIFETIME_ID=...`
- `--dart-define=PRIVACY_URL=https://...` for the hosted privacy policy
- Support email (Contact Us) is set in `lib/core/constants/app_config.dart`
- Release signing: `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`), which is git-ignored.

Debug builds use Google's public test ad units.

### Ads
- Interstitial after every 3 completed levels (3, 6, 9, ...), shown when leaving the result screen. Never during gameplay.
- Rewarded (optional): continue after failing, and double coins on the result screen.
- Either ads-free package disables interstitials. Rewarded ads stay available by choice.
