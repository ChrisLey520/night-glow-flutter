import 'package:in_app_purchase/in_app_purchase.dart';
import 'purchase_repository.dart';

class GooglePlayPurchaseRepository implements PurchaseRepository {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;

  @override
  Future<bool> isAvailable() => InAppPurchase.instance.isAvailable();

  @override
  Future<List<PurchaseProduct>> loadProducts(Set<String> ids) async {
    final response = await InAppPurchase.instance.queryProductDetails(ids);
    return response.productDetails
        .map((p) => PurchaseProduct(id: p.id, title: p.title, price: p.price, raw: p))
        .toList();
  }

  @override
  Future<void> buyProduct(PurchaseProduct product) async {
    // Google Play subscriptions use buyNonConsumable via the unified plugin;
    // the underlying plugin routes this to launchBillingFlow automatically.
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product.raw),
    );
  }

  @override
  Future<void> restorePurchases() =>
      InAppPurchase.instance.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails details) async {
    // On Google Play, consumables need acknowledgment. Our products are
    // subscriptions (non-consumable), so we only call completePurchase
    // when the plugin marks it as pending.
    if (details.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(details);
    }
  }

  @override
  String get subscriptionTermsText =>
      '订阅将在到期前 24 小时内通过 Google Play 自动续费。'
      '可在 Google Play → 订阅 中管理或取消。';
}
