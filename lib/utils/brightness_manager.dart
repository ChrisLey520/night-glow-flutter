import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class BrightnessManager {
  static Future<void> setFullBrightness() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      await WakelockPlus.enable();
    } catch (_) {}
  }

  static Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightness.instance
          .setApplicationScreenBrightness(value.clamp(0.01, 1.0));
    } catch (_) {}
  }

  static Future<void> resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
      await WakelockPlus.disable();
    } catch (_) {}
  }

  static Future<double> getCurrentBrightness() async {
    try {
      return await ScreenBrightness.instance.application;
    } catch (_) {
      return 1.0;
    }
  }
}
