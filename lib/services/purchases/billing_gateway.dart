import 'package:in_app_purchase/in_app_purchase.dart';

/// Thin seam over Google Play Billing (via `in_app_purchase`) so the purchase
/// logic can be tested without a real store.
abstract class BillingGateway {
  Future<bool> isAvailable();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<List<ProductDetails>> queryProducts(Set<String> ids);

  /// Starts the Google Play purchase sheet. Subscriptions and one-time
  /// products are both bought through the non-consumable flow on Android.
  Future<bool> buy(ProductDetails product);

  /// Re-queries Google Play for owned products and active subscriptions.
  /// Results (possibly an empty list) arrive on [purchaseStream].
  Future<void> restore();

  /// Acknowledges a purchase (required by Google Play within 3 days).
  Future<void> complete(PurchaseDetails purchase);
}

class PlayBillingGateway implements BillingGateway {
  PlayBillingGateway([InAppPurchase? iap]) : _iap = iap ?? InAppPurchase.instance;
  final InAppPurchase _iap;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<List<ProductDetails>> queryProducts(Set<String> ids) async {
    final resp = await _iap.queryProductDetails(ids);
    return resp.productDetails;
  }

  @override
  Future<bool> buy(ProductDetails product) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(PurchaseDetails purchase) => _iap.completePurchase(purchase);
}
