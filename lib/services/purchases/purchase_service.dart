import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/app_config.dart';
import '../storage/storage_service.dart';

/// Hook for purchase verification. The default verifier performs local
/// sanity checks; for production, implement a server-side verifier that
/// validates `serverVerificationData` with the Google Play Developer API.
abstract class PurchaseVerifier {
  Future<bool> verify(PurchaseDetails details);
}

class LocalPurchaseVerifier implements PurchaseVerifier {
  const LocalPurchaseVerifier(this.productId);
  final String productId;

  @override
  Future<bool> verify(PurchaseDetails details) async {
    return details.productID == productId && details.verificationData.serverVerificationData.isNotEmpty;
  }
}

enum PurchaseUiState { idle, loading, pending, success, error }

/// Lifetime "Remove Ads" (non-consumable) through Google Play Billing.
/// Never grants the entitlement without a verified purchase.
class PurchaseService extends ChangeNotifier {
  PurchaseService(this._storage, {InAppPurchase? iap, PurchaseVerifier? verifier})
      : _iap = iap,
        _verifier = verifier ?? const LocalPurchaseVerifier(AppConfig.removeAdsProductId),
        _removeAds = _storage.getBool(_kRemoveAds);

  /// Offline/test instance that never touches the store.
  PurchaseService.offline(this._storage)
      : _iap = null,
        _verifier = const LocalPurchaseVerifier(AppConfig.removeAdsProductId),
        _removeAds = _storage.getBool(_kRemoveAds);

  static const _kRemoveAds = 'purchases.removeAds';

  final StorageService _storage;
  final InAppPurchase? _iap;
  final PurchaseVerifier _verifier;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _removeAds;
  bool _available = false;
  ProductDetails? _product;
  PurchaseUiState state = PurchaseUiState.idle;
  String? message;

  bool get removeAds => _removeAds;
  bool get storeAvailable => _available;

  /// Localised price from Google Play (never hardcoded).
  String? get price => _product?.price;

  Future<void> init() async {
    final iap = _iap;
    if (iap == null) return;
    try {
      _available = await iap.isAvailable();
      if (!_available) return;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        _setState(PurchaseUiState.error, 'Purchase failed. Please try again.');
      });
      final resp = await iap.queryProductDetails({AppConfig.removeAdsProductId});
      if (resp.productDetails.isNotEmpty) _product = resp.productDetails.first;
      notifyListeners();
    } catch (e) {
      debugPrint('purchases: init failed: $e');
      _available = false;
    }
  }

  Future<void> buyRemoveAds() async {
    if (_removeAds) return;
    final iap = _iap;
    final product = _product;
    if (iap == null || !_available || product == null) {
      _setState(PurchaseUiState.error, 'The store is not available right now. Check your connection and try again.');
      return;
    }
    _setState(PurchaseUiState.loading, null);
    try {
      final started = await iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) _setState(PurchaseUiState.error, 'Could not start the purchase.');
    } catch (e) {
      _setState(PurchaseUiState.error, 'Could not start the purchase.');
    }
  }

  Future<void> restore() async {
    final iap = _iap;
    if (iap == null || !_available) {
      _setState(PurchaseUiState.error, 'The store is not available right now.');
      return;
    }
    _setState(PurchaseUiState.loading, null);
    try {
      await iap.restorePurchases();
      // Restored purchases arrive on the stream; if none arrive, report that.
      Future.delayed(const Duration(seconds: 4), () {
        if (state == PurchaseUiState.loading) {
          _setState(PurchaseUiState.idle, _removeAds ? 'Purchases restored.' : 'No previous purchases found.');
        }
      });
    } catch (e) {
      _setState(PurchaseUiState.error, 'Restore failed. Please try again.');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != AppConfig.removeAdsProductId) {
        if (p.pendingCompletePurchase) await _iap?.completePurchase(p);
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.pending:
          _setState(PurchaseUiState.pending, 'Purchase pending…');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final ok = await _verifier.verify(p);
          if (ok) {
            await _grant();
            _setState(PurchaseUiState.success,
                p.status == PurchaseStatus.restored ? 'Purchases restored.' : 'Ads removed. Thank you!');
          } else {
            _setState(PurchaseUiState.error, 'We could not verify this purchase.');
          }
        case PurchaseStatus.error:
          _setState(PurchaseUiState.error, p.error?.message ?? 'Purchase failed.');
        case PurchaseStatus.canceled:
          _setState(PurchaseUiState.idle, null);
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap?.completePurchase(p);
        } catch (e) {
          debugPrint('purchases: completePurchase failed: $e');
        }
      }
    }
  }

  Future<void> _grant() async {
    _removeAds = true;
    await _storage.setBool(_kRemoveAds, true);
  }

  void _setState(PurchaseUiState s, String? msg) {
    state = s;
    message = msg;
    notifyListeners();
  }

  void clearMessage() {
    message = null;
    if (state != PurchaseUiState.loading && state != PurchaseUiState.pending) state = PurchaseUiState.idle;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
