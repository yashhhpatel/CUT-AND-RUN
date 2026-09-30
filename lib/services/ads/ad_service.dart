import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/app_config.dart';
import '../purchases/purchase_service.dart';
import '../storage/storage_service.dart';

/// Isolated AdMob integration. Ads are only ever shown at natural breaks
/// (after results / on explicit rewarded choice) — never during gameplay.
/// Every failure degrades gracefully to "no ad".
class AdService {
  AdService(this._storage, this._purchases, {this.enabled = true});

  /// No-op instance for tests.
  AdService.disabled(this._storage, this._purchases) : enabled = false;

  final StorageService _storage;
  final PurchaseService _purchases;
  final bool enabled;

  late final InterstitialPacer pacer = InterstitialPacer(_storage);

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  bool _initialized = false;
  bool _loadingInterstitial = false;
  bool _loadingRewarded = false;

  bool get rewardedReady => _rewarded != null;

  Future<void> init() async {
    if (!enabled) return;
    try {
      await _gatherConsent();
      if (!await ConsentInformation.instance.canRequestAds()) {
        // Consent not obtained yet; try again next launch.
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('ads: init failed: $e');
    }
  }

  /// Google UMP consent flow (required for EEA/UK users).
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            ConsentForm.loadAndShowConsentFormIfRequired((_) {
              if (!done.isCompleted) done.complete();
            });
          } catch (_) {
            if (!done.isCompleted) done.complete();
          }
        },
        (_) {
          if (!done.isCompleted) done.complete();
        },
      );
    } catch (_) {
      if (!done.isCompleted) done.complete();
    }
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  void _loadInterstitial() {
    if (!_initialized || _purchases.removeAds || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          debugPrint('ads: interstitial failed: ${err.message}');
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!_initialized || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          debugPrint('ads: rewarded failed: ${err.message}');
        },
      ),
    );
  }

  /// Call when a level is completed and the player leaves the result screen.
  Future<void> maybeShowInterstitial({required int levelJustCompleted}) async {
    if (!enabled || _purchases.removeAds) return;
    if (!await pacer.registerCompletion()) return;
    final ad = _interstitial;
    if (ad == null) {
      // Not loaded yet: stay due and try again after the next level.
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    await pacer.reset();
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
        _loadInterstitial();
      },
    );
    try {
      await ad.show();
      await closed.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    } catch (e) {
      debugPrint('ads: show interstitial failed: $e');
    }
  }

  /// Shows a rewarded ad. Resolves true only if the reward was earned.
  Future<bool> showRewarded() async {
    if (!enabled) return false;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        if (!closed.isCompleted) closed.complete();
        _loadRewarded();
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
      await closed.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    } catch (e) {
      debugPrint('ads: show rewarded failed: $e');
    }
    return earned;
  }

  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
  }
}

/// Decides when an interstitial is due: after every
/// [AppConfig.interstitialEveryNLevels] completed levels (3, 6, 9, ...).
/// The count is persisted, so it carries over between sessions.
class InterstitialPacer {
  InterstitialPacer(this._storage);

  final StorageService _storage;
  static const _kCompletedSinceAd = 'ads.completedSinceInterstitial';

  int get completedSinceAd => _storage.getInt(_kCompletedSinceAd);

  /// Records a completed level. Returns true when an interstitial is due.
  Future<bool> registerCompletion() async {
    final count = completedSinceAd + 1;
    await _storage.setInt(_kCompletedSinceAd, count);
    return count >= AppConfig.interstitialEveryNLevels;
  }

  /// Call after an interstitial was actually shown.
  Future<void> reset() => _storage.setInt(_kCompletedSinceAd, 0);
}
