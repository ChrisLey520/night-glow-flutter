/// Platform-agnostic purchase models — no dependency on any store SDK.

enum StorePurchaseStatus { pending, purchased, restored, cancelled, error }

/// Unified purchase event produced by every store implementation.
class StorePurchaseUpdate {
  final String productId;
  final StorePurchaseStatus status;
  /// Whether the implementation needs [PurchaseRepository.completePurchase]
  /// to be called to close the transaction on the store side.
  final bool needsFinish;

  const StorePurchaseUpdate({
    required this.productId,
    required this.status,
    this.needsFinish = false,
  });
}

/// Product info shown in the UI — no raw SDK type exposed.
class PurchaseProduct {
  final String id;
  final String title;
  final String price;

  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.price,
  });
}

/// Abstract interface — all store implementations must satisfy this contract.
/// MembershipManager and UI depend only on this; they never touch SDK types.
abstract class PurchaseRepository {
  /// Stream of purchase events. Subscribe once on app start.
  Stream<List<StorePurchaseUpdate>> get purchaseStream;

  /// Whether the store billing service is reachable on this device.
  Future<bool> isAvailable();

  /// Fetch localised product info for [ids].
  Future<List<PurchaseProduct>> loadProducts(Set<String> ids);

  /// Initiate a purchase flow. The result arrives via [purchaseStream].
  Future<void> buyProduct(PurchaseProduct product);

  /// Restore previously completed purchases (App Store / Google Play).
  /// Chinese stores usually don't need this — no-op is fine.
  Future<void> restorePurchases();

  /// Acknowledge / finish the transaction so the store closes it.
  /// Only call when [StorePurchaseUpdate.needsFinish] is true.
  Future<void> completePurchase(StorePurchaseUpdate update);

  /// Store-specific subscription terms shown below the buy button.
  String get subscriptionTermsText;
}
