import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/membership_level.dart';
import 'state_store.dart';

class MembershipManager {
  final StateStore _store;
  MembershipLevel _level = MembershipLevel.normal;

  MembershipManager(this._store);

  MembershipLevel get level => _level;

  Future<void> init() async {
    _level = _store.membershipLevel;
    await _restoreFromStore();
  }

  Future<void> _restoreFromStore() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) return;
      await InAppPurchase.instance.restorePurchases();
      // purchases are handled via purchaseStream — see HomePage
    } catch (_) {}
  }

  Future<List<ProductDetails>> loadProducts() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) return [];

      final ids = {
        MembershipProducts.vipProductId,
        MembershipProducts.svipProductId,
      };
      final response = await InAppPurchase.instance.queryProductDetails(ids);
      return response.productDetails;
    } catch (_) {
      return [];
    }
  }

  Future<bool> purchase(ProductDetails product) async {
    try {
      final param = PurchaseParam(productDetails: product);
      return await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: param,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> applyPurchase(PurchaseDetails details) async {
    if (details.status == PurchaseStatus.purchased ||
        details.status == PurchaseStatus.restored) {
      MembershipLevel newLevel;
      if (details.productID == MembershipProducts.svipProductId) {
        newLevel = MembershipLevel.svip;
      } else if (details.productID == MembershipProducts.vipProductId) {
        newLevel = MembershipLevel.vip;
      } else {
        return;
      }
      if (newLevel.value > _level.value) {
        _level = newLevel;
        await _store.saveMembershipLevel(newLevel);
      }
      if (details.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(details);
      }
    } else if (details.status == PurchaseStatus.error ||
        details.status == PurchaseStatus.canceled) {
      // Fix: Android requires completePurchase even for error/canceled states
      // to prevent the transaction from hanging indefinitely in the pending queue.
      if (details.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(details);
        } catch (e) {
          debugPrint('completePurchase on error/canceled failed: $e');
        }
      }
    }
  }
  // Fix #10: removed canAccessPreset() dead code — access gating is handled
  // exclusively by ControlPanel using preset.requiredLevel from the data model,
  // which is the single source of truth and avoids logic divergence.
}
