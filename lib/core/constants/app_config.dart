/// Environment-specific configuration. Production values are injected at build
/// time with `--dart-define` so no real IDs or secrets live in the repository.
///
/// Example release build:
/// flutter build appbundle \
///   --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-xxx/yyy \
///   --dart-define=ADMOB_REWARDED_ID=ca-app-pub-xxx/zzz \
///   --dart-define=REMOVE_ADS_PRODUCT_ID=remove_ads
abstract final class AppConfig {
  // Google's public test ad units. Safe to ship in debug builds only.
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const interstitialAdUnitId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: _testInterstitial);
  static const rewardedAdUnitId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: _testRewarded);

  /// Non-consumable Google Play product that removes interstitial ads forever.
  static const removeAdsProductId = String.fromEnvironment('REMOVE_ADS_PRODUCT_ID', defaultValue: 'remove_ads');

  /// Show an interstitial at most once every N completed levels.
  static const interstitialEveryNLevels = 3;

  /// Never show interstitials before the player has finished this many levels.
  static const interstitialMinLevel = 5;

  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
  static const playStorePackage = 'com.cutandrun.game';
}
