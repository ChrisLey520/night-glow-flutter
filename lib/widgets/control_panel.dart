import 'package:flutter/material.dart';
import '../models/color_model.dart';
import '../models/preset_data.dart';
import '../models/membership_level.dart';
import '../models/custom_image_preset.dart';
import '../repositories/custom_preset_repository.dart';
import 'preset_card_list.dart';
import 'color_wheel.dart';

class ControlPanel extends StatefulWidget {
  final int selectedIndex;
  final ColorModel customColor;
  final double screenBrightness;
  final MembershipLevel memberLevel;
  final String? selectedCustomPresetId;
  final List<CustomImagePreset> customPresets;
  final CustomPresetRepository repository;
  final ValueChanged<int> onPresetSelected;
  final ValueChanged<ColorModel> onColorChanged;
  final ValueChanged<double> onBrightnessChanged;
  final VoidCallback onMembershipRequired;
  final ValueChanged<CustomImagePreset> onCustomSelected;
  final ValueChanged<List<CustomImagePreset>> onCustomPresetsChanged;

  const ControlPanel({
    super.key,
    required this.selectedIndex,
    required this.customColor,
    required this.screenBrightness,
    required this.memberLevel,
    required this.selectedCustomPresetId,
    required this.customPresets,
    required this.repository,
    required this.onPresetSelected,
    required this.onColorChanged,
    required this.onBrightnessChanged,
    required this.onMembershipRequired,
    required this.onCustomSelected,
    required this.onCustomPresetsChanged,
  });

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    if (widget.selectedIndex < kPresets.length &&
        kPresets[widget.selectedIndex].isCustom) {
      _animController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handlePresetSelected(int index) {
    final preset = kPresets[index];
    final locked = widget.memberLevel.value < preset.requiredLevel.value;
    if (locked) {
      widget.onMembershipRequired();
      return;
    }
    widget.onPresetSelected(index);
    if (preset.isCustom) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void didUpdateWidget(ControlPanel old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != old.selectedIndex ||
        widget.selectedCustomPresetId != old.selectedCustomPresetId) {
      final isBuiltInCustom = widget.selectedCustomPresetId == null &&
          widget.selectedIndex < kPresets.length &&
          kPresets[widget.selectedIndex].isCustom;
      if (isBuiltInCustom) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          PresetCardList(
            selectedIndex: widget.selectedIndex,
            memberLevel: widget.memberLevel,
            selectedCustomPresetId: widget.selectedCustomPresetId,
            customPresets: widget.customPresets,
            repository: widget.repository,
            onSelected: _handlePresetSelected,
            onCustomSelected: widget.onCustomSelected,
            onCustomPresetsChanged: widget.onCustomPresetsChanged,
          ),
          SizeTransition(
            sizeFactor: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: SizedBox(
                height: 180,
                child: ColorWheel(
                  hue: widget.customColor.hue,
                  saturation: widget.customColor.saturation,
                  onHueChanged: (h) =>
                      widget.onColorChanged(widget.customColor.copyWith(hue: h)),
                  onSaturationChanged: (s) => widget
                      .onColorChanged(widget.customColor.copyWith(saturation: s)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                const Icon(Icons.brightness_low,
                    color: Colors.white54, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: widget.screenBrightness,
                      min: 0.05,
                      max: 1.0,
                      onChanged: widget.onBrightnessChanged,
                    ),
                  ),
                ),
                const Icon(Icons.brightness_high,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
