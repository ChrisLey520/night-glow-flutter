import 'package:in_app_purchase/in_app_purchase.dart';

/// Platform-agnostic product info shown in the UI.
class PurchaseProduct {
  final String id;
  final String title;
  final String price;
  final ProductDetails raw;

  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.raw,
  });
}

/// Result of a purchase stream event after the repository processes it.
enum PurchaseOutcome { purchased, restored, cancelled, error, pending }

class PurchaseResult {
  final PurchaseOutcome outcome;
  final String productId;

  const PurchaseResult({required this.outcome, required this.productId});
}

/// Abstract interface — UI and MembershipManager depend only on this.
abstract class PurchaseRepository {
  /// Subscribe to raw purchase events. Call this once on app start.
  Stream<List<PurchaseDetails>> get purchaseStream;

  /// Whether the store is reachable.
  Future<bool> isAvailable();

  /// Fetch product details for [ids].
  Future<List<PurchaseProduct>> loadProducts(Set<String> ids);

  /// Initiate a purchase. Result comes via [purchaseStream].
  Future<void> buyProduct(PurchaseProduct product);

  /// Restore previous purchases. Results come via [purchaseStream].
  Future<void> restorePurchases();

  /// Must be called for every PurchaseDetails to close the transaction.
  Future<void> completePurchase(PurchaseDetails details);

  /// Subscription terms text shown in the payment UI.
  String get subscriptionTermsText;
}
