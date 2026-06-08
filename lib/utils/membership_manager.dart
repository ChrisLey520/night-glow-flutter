import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/membership_level.dart';
import '../repositories/purchase/purchase_repository.dart';
import 'state_store.dart';

class MembershipManager {
  final StateStore _store;
  final PurchaseRepository _repo;
  MembershipLevel _level = MembershipLevel.normal;

  MembershipManager(this._store, this._repo);

  MembershipLevel get level => _level;
  PurchaseRepository get repo => _repo;

  Future<void> init() async {
    _level = _store.membershipLevel;
    await _restoreFromStore();
  }

  Future<void> _restoreFromStore() async {
    try {
      final available = await _repo.isAvailable();
      if (!available) return;
      await _repo.restorePurchases();
    } catch (_) {}
  }

  Future<void> restorePurchases() async => _restoreFromStore();

  Future<List<PurchaseProduct>> loadProducts() async {
    try {
      final available = await _repo.isAvailable();
      if (!available) return [];
      return await _repo.loadProducts({
        MembershipProducts.vipProductId,
        MembershipProducts.svipProductId,
      });
    } catch (_) {
      return [];
    }
  }

  Future<void> purchase(PurchaseProduct product) async {
    try {
      await _repo.buyProduct(product);
    } catch (_) {}
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
      await _repo.completePurchase(details);
    } else if (details.status == PurchaseStatus.error ||
        details.status == PurchaseStatus.canceled) {
      try {
        await _repo.completePurchase(details);
      } catch (e) {
        debugPrint('completePurchase on error/canceled failed: $e');
      }
    }
  }
}
