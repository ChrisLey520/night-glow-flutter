import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'purchase_repository.dart';

class AppStorePurchaseRepository implements PurchaseRepository {
  // Cache raw ProductDetails so buyProduct can look them up by id.
  final Map<String, ProductDetails> _rawProducts = {};

  // Convert the in_app_purchase stream to our store-agnostic type.
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
    final raw = _rawProducts[update.productId];
    if (raw == null) return;
    // completePurchase needs the original PurchaseDetails; we can't recover it
    // here, so the caller (MembershipManager) must call the plugin directly.
    // This method is intentionally a no-op for App Store — the manager calls
    // InAppPurchase.instance.completePurchase in applyPurchase.
  }

  @override
  String get subscriptionTermsText =>
      '订阅将在到期前 24 小时内自动续费并从 Apple 账户扣款。'
      '可在 iPhone 设置 → Apple ID → 订阅 中管理或取消。';

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
