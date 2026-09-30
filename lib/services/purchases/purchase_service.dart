import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/app_config.dart';
import '../storage/storage_service.dart';
import 'billing_gateway.dart';

/// The two ads-free packages sold through Google Play Billing.
enum AdFreePlan {
  /// Auto-renewing monthly subscription.
  monthly,

  /// One-time, non-consumable purchase.
  lifetime,
}

extension AdFreePlanInfo on AdFreePlan {
  String get productId => this == AdFreePlan.monthly ? AppConfig.adsFreeMonthlyId : AppConfig.adsFreeLifetimeId;

  String get title => this == AdFreePlan.monthly ? '1 Month Ads-Free' : 'Lifetime Ads-Free';

  /// Shown only until Google Play returns the real localised price.
  String get fallbackPrice => this == AdFreePlan.monthly ? '₹299' : '₹2,999';
}

/// Hook for purchase verification. The default verifier performs local
/// sanity checks; for stronger protection, implement a server-side verifier
/// that validates `serverVerificationData` with the Google Play Developer API.
abstract class PurchaseVerifier {
  Future<bool> verify(PurchaseDetails details);
}

class LocalPurchaseVerifier implements PurchaseVerifier {
  const LocalPurchaseVerifier();

  @override
  Future<bool> verify(PurchaseDetails details) async {
    final known = AdFreePlan.values.any((p) => p.productId == details.productID);
    return known && details.verificationData.serverVerificationData.isNotEmpty;
  }
}

enum PurchaseUiState { idle, loading, pending, success, error }

/// Ads-free entitlement through Google Play Billing.
///
/// * Lifetime: owned forever once verified.
/// * Monthly: Google Play is re-checked on every launch / restore. If Play no
///   longer reports the subscription (cancelled and expired, refunded) ads
///   come back. While offline, a confirmed subscription stays valid for
///   [offlineGrace] after the last successful check.
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._storage, {BillingGateway? billing, PurchaseVerifier? verifier, DateTime Function()? clock})
      : _billing = billing ?? PlayBillingGateway(),
        _verifier = verifier ?? const LocalPurchaseVerifier(),
        _now = clock ?? DateTime.now {
    _load();
  }

  /// Offline/test instance that never touches the store.
  PurchaseService.offline(this._storage)
      : _billing = null,
        _verifier = const LocalPurchaseVerifier(),
        _now = DateTime.now {
    _load();
  }

  static const offlineGrace = Duration(days: 7);
  static const _kLifetime = 'purchases.lifetime';
  static const _kMonthlyUntil = 'purchases.monthlyUntil';
  static const _kLegacyRemoveAds = 'purchases.removeAds';

  final StorageService _storage;
  final BillingGateway? _billing;
  final PurchaseVerifier _verifier;
  final DateTime Function() _now;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _lifetime = false;
  DateTime? _monthlyUntil;
  bool _available = false;
  final Map<AdFreePlan, ProductDetails> _products = {};

  /// True while waiting for the result of a restore/sync query.
  bool _syncInFlight = false;

  /// Whether the running sync was started by the user (shows a message).
  bool _userRestore = false;

  PurchaseUiState state = PurchaseUiState.idle;
  String? message;

  bool get storeAvailable => _available;
  bool get lifetimeOwned => _lifetime;
  bool get monthlyActive => _monthlyUntil != null && _now().isBefore(_monthlyUntil!);
  bool get removeAds => _lifetime || monthlyActive;
  bool get busy => state == PurchaseUiState.loading || state == PurchaseUiState.pending;

  String priceFor(AdFreePlan plan) => _products[plan]?.price ?? plan.fallbackPrice;
  bool productLoaded(AdFreePlan plan) => _products.containsKey(plan);
  bool owns(AdFreePlan plan) => plan == AdFreePlan.lifetime ? _lifetime : monthlyActive;

  void _load() {
    _lifetime = _storage.getBool(_kLifetime) || _storage.getBool(_kLegacyRemoveAds);
    final until = _storage.getInt(_kMonthlyUntil);
    _monthlyUntil = until > 0 ? DateTime.fromMillisecondsSinceEpoch(until) : null;
  }

  Future<void> _persist() async {
    await _storage.setBool(_kLifetime, _lifetime);
    await _storage.setInt(_kMonthlyUntil, _monthlyUntil?.millisecondsSinceEpoch ?? 0);
  }

  Future<void> init() async {
    final billing = _billing;
    if (billing == null) return;
    try {
      _available = await billing.isAvailable();
      if (!_available) {
        notifyListeners();
        return;
      }
      _sub = billing.purchaseStream.listen(_onPurchases, onError: (Object e) {
        _syncInFlight = false;
        _setState(PurchaseUiState.error, 'Something went wrong with Google Play. Please try again.');
      });
      final products = await billing.queryProducts({for (final p in AdFreePlan.values) p.productId});
      for (final plan in AdFreePlan.values) {
        final match = products.where((d) => d.id == plan.productId);
        if (match.isNotEmpty) _products[plan] = match.first;
      }
      notifyListeners();
      // Silently re-check what this Google account owns.
      await _sync(userInitiated: false);
    } catch (e) {
      debugPrint('purchases: init failed: $e');
      _available = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> buy(AdFreePlan plan) async {
    if (busy) return;
    if (_lifetime) {
      _setState(PurchaseUiState.success, 'You already own Lifetime Ads-Free.');
      return;
    }
    if (plan == AdFreePlan.monthly && monthlyActive) {
      _setState(PurchaseUiState.success, '1 Month Ads-Free is already active.');
      return;
    }
    final billing = _billing;
    final product = _products[plan];
    if (billing == null || !_available || product == null) {
      _setState(PurchaseUiState.error, 'Google Play is not available right now. Check your connection and try again.');
      return;
    }
    _setState(PurchaseUiState.loading, null);
    try {
      final started = await billing.buy(product);
      if (!started) _setState(PurchaseUiState.error, 'Could not open Google Play. Please try again.');
    } catch (e) {
      final text = e.toString();
      if (_isAlreadyOwned(text)) {
        await _handleAlreadyOwned();
      } else {
        _setState(PurchaseUiState.error, 'Could not start the purchase. Please try again.');
      }
    }
  }

  /// User-initiated "Restore Purchases".
  Future<void> restore() => _sync(userInitiated: true);

  Future<void> _sync({required bool userInitiated}) async {
    final billing = _billing;
    if (billing == null || !_available) {
      if (userInitiated) _setState(PurchaseUiState.error, 'Google Play is not available right now.');
      return;
    }
    _syncInFlight = true;
    _userRestore = userInitiated;
    if (userInitiated) _setState(PurchaseUiState.loading, null);
    try {
      await billing.restore();
    } catch (e) {
      _syncInFlight = false;
      debugPrint('purchases: restore failed: $e');
      // Keep cached entitlements when Play can't be reached.
      if (userInitiated) {
        _setState(PurchaseUiState.error, 'Restore failed. Please check your connection and try again.');
      }
    }
  }

  // ----------------------------------------------------------------- stream

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    final isSyncResult = _syncInFlight && list.every((p) => p.status == PurchaseStatus.restored);
    if (isSyncResult) {
      await _applySync(list);
      return;
    }
    for (final p in list) {
      final plan = _planFor(p.productID);
      if (plan == null) {
        await _complete(p);
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.pending:
          _setState(
              PurchaseUiState.pending, 'Payment pending. Ads will be removed as soon as Google Play confirms it.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (await _verifier.verify(p)) {
            await _grant(plan);
            _setState(
              PurchaseUiState.success,
              plan == AdFreePlan.lifetime
                  ? 'Lifetime Ads-Free unlocked. Thank you!'
                  : '1 Month Ads-Free is now active. Thank you!',
            );
          } else {
            _setState(PurchaseUiState.error, 'We could not verify this purchase.');
          }
        case PurchaseStatus.error:
          final err = '${p.error?.code} ${p.error?.message} ${p.error?.details}';
          if (_isAlreadyOwned(err)) {
            await _handleAlreadyOwned();
          } else {
            _setState(PurchaseUiState.error, 'Purchase failed. You have not been charged.');
          }
        case PurchaseStatus.canceled:
          _setState(PurchaseUiState.idle, 'Purchase cancelled.');
      }
      await _complete(p);
    }
  }

  /// Google Play is the source of truth after a successful query.
  Future<void> _applySync(List<PurchaseDetails> owned) async {
    _syncInFlight = false;
    var lifetime = false;
    var monthly = false;
    for (final p in owned) {
      final plan = _planFor(p.productID);
      if (plan == null || !await _verifier.verify(p)) {
        await _complete(p);
        continue;
      }
      if (plan == AdFreePlan.lifetime) lifetime = true;
      if (plan == AdFreePlan.monthly) monthly = true;
      await _complete(p);
    }
    _lifetime = lifetime;
    _monthlyUntil = monthly ? _now().add(offlineGrace) : null;
    await _persist();
    if (_userRestore) {
      _userRestore = false;
      if (lifetime || monthly) {
        _setState(PurchaseUiState.success, lifetime ? 'Lifetime Ads-Free restored.' : '1 Month Ads-Free restored.');
      } else {
        _setState(PurchaseUiState.idle, 'No previous purchases found on this Google account.');
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> _handleAlreadyOwned() async {
    _setState(PurchaseUiState.loading, 'You already own this. Restoring it now…');
    await _sync(userInitiated: true);
  }

  static bool _isAlreadyOwned(String text) {
    final t = text.toLowerCase();
    return t.contains('itemalreadyowned') || t.contains('already owned') || t.contains('item_already_owned');
  }

  AdFreePlan? _planFor(String productId) {
    for (final p in AdFreePlan.values) {
      if (p.productId == productId) return p;
    }
    return null;
  }

  Future<void> _grant(AdFreePlan plan) async {
    if (plan == AdFreePlan.lifetime) {
      _lifetime = true;
    } else {
      // A fresh purchase is valid for at least a month; renewals are
      // confirmed by the next Google Play check.
      final base = _now().add(const Duration(days: 31));
      if (_monthlyUntil == null || _monthlyUntil!.isBefore(base)) _monthlyUntil = base;
    }
    await _persist();
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await _billing?.complete(p);
    } catch (e) {
      debugPrint('purchases: completePurchase failed: $e');
    }
  }

  void _setState(PurchaseUiState s, String? msg) {
    state = s;
    message = msg;
    notifyListeners();
  }

  void clearMessage() {
    message = null;
    if (!busy) state = PurchaseUiState.idle;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
