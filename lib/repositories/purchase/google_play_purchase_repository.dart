import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'purchase_repository.dart';

class GooglePlayPurchaseRepository implements PurchaseRepository {
  final Map<String, ProductDetails> _rawProducts = {};

  @override
  late final Stream<List<StorePurchaseUpdate>> purchaseStream =
      InAppPurchase.instance.purchaseStream.map(
    (details) => details.map(_toUpdate).toList(),
  );

  @override
  Future<bool> isAvailable() => InAppPurchase.instance.isAvailable();

  @override
  Future<List<PurchaseProduct>> loadProducts(Set<String> ids) async {
    final response = await InAppPurchase.instance.queryProductDetails(ids);
    for (final p in response.productDetails) {
      _rawProducts[p.id] = p;
    }
    return response.productDetails
        .map((p) => PurchaseProduct(id: p.id, title: p.title, price: p.price))
        .toList();
  }

  @override
  Future<void> buyProduct(PurchaseProduct product) async {
    final raw = _rawProducts[product.id];
    if (raw == null) return;
    await InAppPurchase.instance
        .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: raw));
  }

  @override
  Future<void> restorePurchases() =>
      InAppPurchase.instance.restorePurchases();

  @override
  Future<void> completePurchase(StorePurchaseUpdate update) async {
    // On Google Play, MembershipManager calls InAppPurchase.completePurchase
    // directly via applyPurchase — nothing extra needed here.
  }

  @override
  String get subscriptionTermsText =>
      '订阅将在到期前 24 小时内通过 Google Play 自动续费。'
      '可在 Google Play → 订阅 中管理或取消。';

  StorePurchaseUpdate _toUpdate(PurchaseDetails d) {
    final status = switch (d.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased => StorePurchaseStatus.purchased,
      PurchaseStatus.restored => StorePurchaseStatus.restored,
      PurchaseStatus.canceled => StorePurchaseStatus.cancelled,
      PurchaseStatus.error => StorePurchaseStatus.error,
    };
    return StorePurchaseUpdate(
      productId: d.productID,
      status: status,
      needsFinish: d.pendingCompletePurchase,
    );
  }
}
