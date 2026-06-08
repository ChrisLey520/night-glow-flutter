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

  Future<void> restorePurchases() => _restoreFromStore();

  Future<List<PurchaseProduct>> loadProducts() async {
    try {
      final available = await _repo.isAvailable();
      if (!available) return [];
      return _repo.loadProducts({
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

  Future<void> applyPurchase(StorePurchaseUpdate update) async {
    if (update.status == StorePurchaseStatus.purchased ||
        update.status == StorePurchaseStatus.restored) {
      MembershipLevel newLevel;
      if (update.productId == MembershipProducts.svipProductId) {
        newLevel = MembershipLevel.svip;
      } else if (update.productId == MembershipProducts.vipProductId) {
        newLevel = MembershipLevel.vip;
      } else {
        return;
      }
      if (newLevel.value > _level.value) {
        _level = newLevel;
        await _store.saveMembershipLevel(newLevel);
      }
      if (update.needsFinish) {
        await _repo.completePurchase(update);
      }
    } else if (update.status == StorePurchaseStatus.error ||
        update.status == StorePurchaseStatus.cancelled) {
      if (update.needsFinish) {
        try {
          await _repo.completePurchase(update);
        } catch (_) {}
      }
    }
  }
}
