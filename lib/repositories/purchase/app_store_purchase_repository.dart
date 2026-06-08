import 'package:in_app_purchase/in_app_purchase.dart';
import 'purchase_repository.dart';

class AppStorePurchaseRepository implements PurchaseRepository {
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
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product.raw),
    );
  }

  @override
  Future<void> restorePurchases() =>
      InAppPurchase.instance.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails details) =>
      InAppPurchase.instance.completePurchase(details);

  @override
  String get subscriptionTermsText =>
      '订阅将在到期前 24 小时内自动续费并从 Apple 账户扣款。'
      '可在 iPhone 设置 → Apple ID → 订阅 中管理或取消。';
}
