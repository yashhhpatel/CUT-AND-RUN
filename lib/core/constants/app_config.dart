/// Environment-specific configuration. Production values are injected at build
/// time with `--dart-define` so no real IDs or secrets live in the repository.
///
/// Example release build:
/// flutter build appbundle \
///   --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-xxx/yyy \
///   --dart-define=ADMOB_REWARDED_ID=ca-app-pub-xxx/zzz \
///   --dart-define=PRIVACY_URL=https://your-site/privacy
abstract final class AppConfig {
  // Google's public test ad units. Safe to ship in debug builds only.
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const interstitialAdUnitId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: _testInterstitial);
  static const rewardedAdUnitId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: _testRewarded);

  /// Google Play products for the two ads-free packages. Create them in Play
  /// Console with these IDs (or override with --dart-define):
  ///  * Subscription `remove_ads_monthly`, base plan: monthly, auto-renewing, ₹299
  ///  * In-app product (one-time) `remove_ads_lifetime`, ₹2,999
  static const adsFreeMonthlyId = String.fromEnvironment('ADS_FREE_MONTHLY_ID', defaultValue: 'remove_ads_monthly');
  static const adsFreeLifetimeId = String.fromEnvironment('ADS_FREE_LIFETIME_ID', defaultValue: 'remove_ads_lifetime');

  /// Show an interstitial after every N completed levels (3, 6, 9, ...),
  /// when the player leaves the result screen. Never during gameplay.
  static const interstitialEveryNLevels = 3;

  /// Hosted privacy policy. Leave empty to show the built-in summary.
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_URL');

  /// Support address opened by "Contact Us".
  static const supportEmail = 'aakashmangukiya10@gmail.com';
  static const playStorePackage = 'com.cutandrun.game';
}
