import 'dart:async';

import 'package:cut_and_run/services/purchases/billing_gateway.dart';
import 'package:cut_and_run/services/purchases/purchase_service.dart';
import 'package:cut_and_run/services/storage/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scriptable stand-in for Google Play Billing.
class FakeBilling implements BillingGateway {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  List<PurchaseDetails> owned = [];
  bool restoreThrows = false;
  final bought = <String>[];
  final completed = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<List<ProductDetails>> queryProducts(Set<String> ids) async => [
        ProductDetails(
            id: 'remove_ads_monthly',
            title: 'Monthly',
            description: '',
            price: '₹299.00',
            rawPrice: 299,
            currencyCode: 'INR'),
        ProductDetails(
            id: 'remove_ads_lifetime',
            title: 'Lifetime',
            description: '',
            price: '₹2,999.00',
            rawPrice: 2999,
            currencyCode: 'INR'),
      ];

  @override
  Future<bool> buy(ProductDetails product) async {
    bought.add(product.id);
    return true;
  }

  @override
  Future<void> restore() async {
    if (restoreThrows) throw Exception('BillingResponse.serviceUnavailable');
    scheduleMicrotask(() => controller.add([for (final p in owned) p..status = PurchaseStatus.restored]));
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async => completed.add(purchase.productID);

  void emit(List<PurchaseDetails> list) => controller.add(list);
}

PurchaseDetails purchase(String id, PurchaseStatus status, {IAPError? error}) => PurchaseDetails(
      purchaseID: 'order-$id',
      productID: id,
      verificationData: PurchaseVerificationData(
          localVerificationData: '{}', serverVerificationData: 'token-$id', source: 'google_play'),
      transactionDate: '0',
      status: status,
    )
      ..error = error
      ..pendingCompletePurchase = status == PurchaseStatus.purchased || status == PurchaseStatus.restored;

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late StorageService storage;
  late FakeBilling billing;
  var now = DateTime(2026, 10, 1);

  Future<PurchaseService> make() async {
    final s = PurchaseService(storage, billing: billing, clock: () => now);
    await s.init();
    await settle();
    return s;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = await StorageService.create();
    billing = FakeBilling();
    now = DateTime(2026, 10, 1);
  });

  test('shows Google Play prices for both packages', () async {
    final s = await make();
    expect(s.priceFor(AdFreePlan.monthly), '₹299.00');
    expect(s.priceFor(AdFreePlan.lifetime), '₹2,999.00');
    expect(s.removeAds, isFalse);
  });

  test('lifetime purchase removes ads, acknowledges and persists', () async {
    final s = await make();
    await s.buy(AdFreePlan.lifetime);
    expect(billing.bought, ['remove_ads_lifetime']);
    billing.emit([purchase('remove_ads_lifetime', PurchaseStatus.purchased)]);
    await settle();
    expect(s.removeAds, isTrue);
    expect(s.lifetimeOwned, isTrue);
    expect(billing.completed, contains('remove_ads_lifetime'));
    expect(PurchaseService.offline(storage).removeAds, isTrue, reason: 'persisted');
  });

  test('monthly purchase is active and expires when Play stops reporting it', () async {
    final s = await make();
    await s.buy(AdFreePlan.monthly);
    billing.emit([purchase('remove_ads_monthly', PurchaseStatus.purchased)]);
    await settle();
    expect(s.monthlyActive, isTrue);
    // Next launch: subscription was cancelled and has run out.
    billing.owned = [];
    now = now.add(const Duration(days: 40));
    final next = await make();
    expect(next.monthlyActive, isFalse);
    expect(next.removeAds, isFalse);
  });

  test('renewed monthly subscription stays active on the next launch', () async {
    billing.owned = [purchase('remove_ads_monthly', PurchaseStatus.purchased)];
    final s = await make();
    expect(s.monthlyActive, isTrue);
  });

  test('offline launch keeps a recently confirmed subscription', () async {
    billing.owned = [purchase('remove_ads_monthly', PurchaseStatus.purchased)];
    await make();
    billing.restoreThrows = true;
    now = now.add(const Duration(days: 3));
    final offline = await make();
    expect(offline.monthlyActive, isTrue);
    now = now.add(const Duration(days: 10));
    expect(offline.monthlyActive, isFalse, reason: 'grace period is limited');
  });

  test('cancelled purchase grants nothing', () async {
    final s = await make();
    await s.buy(AdFreePlan.lifetime);
    billing.emit([purchase('remove_ads_lifetime', PurchaseStatus.canceled)]);
    await settle();
    expect(s.removeAds, isFalse);
    expect(s.state, PurchaseUiState.idle);
  });

  test('pending purchase waits, then unlocks when confirmed', () async {
    final s = await make();
    await s.buy(AdFreePlan.lifetime);
    billing.emit([purchase('remove_ads_lifetime', PurchaseStatus.pending)]);
    await settle();
    expect(s.state, PurchaseUiState.pending);
    expect(s.removeAds, isFalse);
    billing.emit([purchase('remove_ads_lifetime', PurchaseStatus.purchased)]);
    await settle();
    expect(s.removeAds, isTrue);
  });

  test('restore finds a lifetime purchase', () async {
    final s = await make();
    billing.owned = [purchase('remove_ads_lifetime', PurchaseStatus.purchased)];
    await s.restore();
    await settle();
    expect(s.lifetimeOwned, isTrue);
  });

  test('restore with nothing owned reports it', () async {
    final s = await make();
    String? msg;
    s.addListener(() => msg ??= s.message);
    await s.restore();
    await settle();
    expect(s.removeAds, isFalse);
    expect(msg, contains('No previous purchases'));
  });

  test('already-owned error restores the purchase', () async {
    final s = await make();
    await s.buy(AdFreePlan.lifetime);
    billing.owned = [purchase('remove_ads_lifetime', PurchaseStatus.purchased)];
    billing.emit([
      purchase('remove_ads_lifetime', PurchaseStatus.error,
          error: IAPError(source: 'google_play', code: 'purchase_error', message: 'BillingResponse.itemAlreadyOwned')),
    ]);
    await settle();
    await settle();
    expect(s.lifetimeOwned, isTrue);
  });

  test('buying again when already owned does not open Google Play', () async {
    billing.owned = [purchase('remove_ads_lifetime', PurchaseStatus.purchased)];
    final s = await make();
    await s.buy(AdFreePlan.lifetime);
    await s.buy(AdFreePlan.monthly);
    expect(billing.bought, isEmpty);
  });

  test('failed purchase shows an error and grants nothing', () async {
    final s = await make();
    await s.buy(AdFreePlan.monthly);
    billing.emit([
      purchase('remove_ads_monthly', PurchaseStatus.error,
          error: IAPError(source: 'google_play', code: 'purchase_error', message: 'BillingResponse.error')),
    ]);
    await settle();
    expect(s.removeAds, isFalse);
    expect(s.state, PurchaseUiState.error);
  });

  test('store unavailable: buying explains instead of crashing', () async {
    billing.available = false;
    final s = await make();
    await s.buy(AdFreePlan.lifetime);
    expect(s.state, PurchaseUiState.error);
    expect(s.priceFor(AdFreePlan.lifetime), '₹2,999');
  });
}
