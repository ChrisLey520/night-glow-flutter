import 'dart:async';
import 'package:flutter/services.dart';
import 'purchase_repository.dart';

/// Xiaomi GetApps (小米应用商店) IAP via Mi Pay SDK.
///
/// Native side (Kotlin) to implement:
///   MethodChannel "com.nightglow/xiaomi_iap"
///   Methods: isAvailable, loadProducts, buyProduct, restorePurchases
///   EventChannel "com.nightglow/xiaomi_iap_events" → pushes purchase events
///
/// Required setup:
///   1. Register on Xiaomi Open Platform (dev.mi.com), create app & products
///   2. Download Mi Pay SDK (MiSdk) and add AAR to android/app/libs/
///   3. Add dependency in android/app/build.gradle.kts:
///        implementation(files("libs/MiSdk-release.aar"))
///   4. Implement MethodChannel handler in MainActivity.kt
class XiaomiPurchaseRepository implements PurchaseRepository {
  static const _method = MethodChannel('com.nightglow/xiaomi_iap');
  static const _events = EventChannel('com.nightglow/xiaomi_iap_events');

  final StreamController<List<StorePurchaseUpdate>> _controller =
      StreamController.broadcast();

  XiaomiPurchaseRepository() {
    _events.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final update = _parseEvent(event.cast<String, dynamic>());
        _controller.add([update]);
      }
    }, onError: (_) {});
  }

  @override
  Stream<List<StorePurchaseUpdate>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _method.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<PurchaseProduct>> loadProducts(Set<String> ids) async {
    try {
      final result = await _method.invokeListMethod<Map>(
            'loadProducts', {'ids': ids.toList()}) ??
          [];
      return result.map((m) {
        final map = m.cast<String, dynamic>();
        return PurchaseProduct(
          id: map['id'] as String,
          title: map['title'] as String,
          price: map['price'] as String,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> buyProduct(PurchaseProduct product) async {
    try {
      await _method.invokeMethod<void>('buyProduct', {'id': product.id});
    } catch (_) {}
  }

  @override
  Future<void> restorePurchases() async {
    try {
      await _method.invokeMethod<void>('restorePurchases');
    } catch (_) {}
  }

  @override
  Future<void> completePurchase(StorePurchaseUpdate update) async {
    if (!update.needsFinish) return;
    try {
      await _method
          .invokeMethod<void>('completePurchase', {'id': update.productId});
    } catch (_) {}
  }

  @override
  String get subscriptionTermsText =>
      '订阅将在到期前自动续费并从小米账号余额/绑定支付方式扣款。'
      '可在小米应用商店 → 我的 → 订阅管理 中取消。';

  StorePurchaseUpdate _parseEvent(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'error';
    final status = switch (statusStr) {
      'purchased' => StorePurchaseStatus.purchased,
      'restored' => StorePurchaseStatus.restored,
      'cancelled' => StorePurchaseStatus.cancelled,
      'pending' => StorePurchaseStatus.pending,
      _ => StorePurchaseStatus.error,
    };
    return StorePurchaseUpdate(
      productId: map['productId'] as String? ?? '',
      status: status,
      needsFinish: map['needsFinish'] as bool? ?? false,
    );
  }
}
