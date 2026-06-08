import 'package:shared_preferences/shared_preferences.dart';
import '../models/color_model.dart';
import '../models/membership_level.dart';

class StateStore {
  static const _keyPreviewX = 'preview_x';
  static const _keyPreviewY = 'preview_y';
  static const _keyPreviewW = 'preview_w';
  static const _keyPreviewH = 'preview_h';
  static const _keySelectedIndex = 'selected_index';
  static const _keyHue = 'hue';
  static const _keySaturation = 'saturation';
  static const _keyColorBrightness = 'color_brightness';
  static const _keyScreenBrightness = 'screen_brightness';
  static const _keyMirrorCapture = 'mirror_capture';
  static const _keyMembershipLevel = 'membership_level';
  static const _keySelectedCustomPresetId = 'selected_custom_preset_id';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  double get previewX => _prefs.getDouble(_keyPreviewX) ?? -1.0;
  double get previewY => _prefs.getDouble(_keyPreviewY) ?? -1.0;
  double get previewW => _prefs.getDouble(_keyPreviewW) ?? 160.0;
  double get previewH => _prefs.getDouble(_keyPreviewH) ?? 285.0;
  int get selectedIndex => _prefs.getInt(_keySelectedIndex) ?? 0;
  double get hue => _prefs.getDouble(_keyHue) ?? 0.0;
  double get saturation => _prefs.getDouble(_keySaturation) ?? 1.0;
  double get colorBrightness => _prefs.getDouble(_keyColorBrightness) ?? 1.0;
  double get screenBrightness => _prefs.getDouble(_keyScreenBrightness) ?? 1.0;
  bool get mirrorCapture => (_prefs.getInt(_keyMirrorCapture) ?? 0) == 1;
  MembershipLevel get membershipLevel =>
      MembershipLevel.fromValue(_prefs.getInt(_keyMembershipLevel) ?? 0);
  String? get selectedCustomPresetId =>
      _prefs.getString(_keySelectedCustomPresetId);

  Future<void> savePreviewLayout(double x, double y, double w, double h) async {
    await _prefs.setDouble(_keyPreviewX, x);
    await _prefs.setDouble(_keyPreviewY, y);
    await _prefs.setDouble(_keyPreviewW, w);
    await _prefs.setDouble(_keyPreviewH, h);
  }

  Future<void> saveSelectedIndex(int index) async {
    await _prefs.setInt(_keySelectedIndex, index);
  }

  Future<void> saveColor(ColorModel color) async {
    await _prefs.setDouble(_keyHue, color.hue);
    await _prefs.setDouble(_keySaturation, color.saturation);
    await _prefs.setDouble(_keyColorBrightness, color.brightness);
  }

  Future<void> saveScreenBrightness(double value) async {
    await _prefs.setDouble(_keyScreenBrightness, value);
  }

  Future<void> saveMirrorCapture(bool value) async {
    await _prefs.setInt(_keyMirrorCapture, value ? 1 : 0);
  }

  Future<void> saveMembershipLevel(MembershipLevel level) async {
    await _prefs.setInt(_keyMembershipLevel, level.value);
  }

  Future<void> saveSelectedCustomPresetId(String? id) async {
    if (id == null) {
      await _prefs.remove(_keySelectedCustomPresetId);
    } else {
      await _prefs.setString(_keySelectedCustomPresetId, id);
    }
  }
}
