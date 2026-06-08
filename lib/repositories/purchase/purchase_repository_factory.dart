import 'dart:io';
import 'purchase_repository.dart';
import 'app_store_purchase_repository.dart';
import 'google_play_purchase_repository.dart';
import 'huawei_purchase_repository.dart';
import 'xiaomi_purchase_repository.dart';
import 'oppo_purchase_repository.dart';

/// Injected at build time via --dart-define=STORE_CHANNEL=<value>.
/// Defaults to google_play on Android, app_store on iOS.
///
/// Usage examples:
///   flutter run  --dart-define=STORE_CHANNEL=huawei
///   flutter run  --dart-define=STORE_CHANNEL=xiaomi
///   flutter run  --dart-define=STORE_CHANNEL=oppo
///   flutter build apk --dart-define=STORE_CHANNEL=huawei
const _channel = String.fromEnvironment('STORE_CHANNEL');

class PurchaseRepositoryFactory {
  static PurchaseRepository create() {
    if (Platform.isIOS || Platform.isMacOS) {
      return AppStorePurchaseRepository();
    }

    if (Platform.isAndroid) {
      return switch (_channel) {
        'huawei' => HuaweiPurchaseRepository(),
        'xiaomi' => XiaomiPurchaseRepository(),
        'oppo'   => OppoPurchaseRepository(),
        _        => GooglePlayPurchaseRepository(), // default
      };
    }

    return AppStorePurchaseRepository();
  }
}
