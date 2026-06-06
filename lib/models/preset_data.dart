import 'color_model.dart';
import 'membership_level.dart';

class PresetItem {
  final int id;
  final String name;
  final ColorModel color;
  final bool isCustom;
  final MembershipLevel requiredLevel;

  const PresetItem({
    required this.id,
    required this.name,
    required this.color,
    this.isCustom = false,
    required this.requiredLevel,
  });
}

const List<PresetItem> kPresets = [
  PresetItem(
    id: 0,
    name: '柔白光',
    color: ColorModel(hue: 40, saturation: 0.08, brightness: 1.0),
    requiredLevel: MembershipLevel.normal,
  ),
  PresetItem(
    id: 1,
    name: '暖阳金',
    color: ColorModel(hue: 38, saturation: 0.55, brightness: 1.0),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 2,
    name: '蜜桃晕',
    color: ColorModel(hue: 10, saturation: 0.40, brightness: 1.0),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 3,
    name: '少女感',
    color: ColorModel(hue: 340, saturation: 0.35, brightness: 1.0),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 4,
    name: '日光白',
    color: ColorModel(hue: 200, saturation: 0.10, brightness: 1.0),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 5,
    name: '月光冷',
    color: ColorModel(hue: 220, saturation: 0.30, brightness: 0.95),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 6,
    name: '氛围紫',
    color: ColorModel(hue: 270, saturation: 0.50, brightness: 0.90),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 7,
    name: '胶片黄',
    color: ColorModel(hue: 50, saturation: 0.60, brightness: 0.95),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 8,
    name: '赛博橙',
    color: ColorModel(hue: 25, saturation: 0.80, brightness: 1.0),
    requiredLevel: MembershipLevel.vip,
  ),
  PresetItem(
    id: 9,
    name: '自定义',
    color: ColorModel(hue: 0, saturation: 1.0, brightness: 1.0),
    isCustom: true,
    requiredLevel: MembershipLevel.svip,
  ),
];
