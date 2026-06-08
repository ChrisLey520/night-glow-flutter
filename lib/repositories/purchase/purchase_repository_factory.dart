import 'dart:io';
import 'purchase_repository.dart';
import 'app_store_purchase_repository.dart';
import 'google_play_purchase_repository.dart';

class PurchaseRepositoryFactory {
  static PurchaseRepository create() {
    if (Platform.isIOS || Platform.isMacOS) {
      return AppStorePurchaseRepository();
    }
    if (Platform.isAndroid) {
      return GooglePlayPurchaseRepository();
    }
    // Fallback: unsupported platform returns App Store impl which will
    // report isAvailable() = false and show graceful error in the UI.
    return AppStorePurchaseRepository();
  }
}
