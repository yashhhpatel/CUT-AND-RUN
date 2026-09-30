# Cut & Run

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
- `--dart-define=REMOVE_ADS_PRODUCT_ID=remove_ads` (create this non-consumable product in Play Console)
- Optional: `PRIVACY_URL`, `TERMS_URL`, `SUPPORT_EMAIL`
- Release signing: `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`), which is git-ignored.

Debug builds use Google's public test ad units.
