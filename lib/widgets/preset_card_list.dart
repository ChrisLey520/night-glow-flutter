import 'package:flutter/material.dart';
import '../models/preset_data.dart';
import '../models/membership_level.dart';

class PresetCardList extends StatefulWidget {
  final int selectedIndex;
  final MembershipLevel memberLevel;
  final ValueChanged<int> onSelected;

  const PresetCardList({
    super.key,
    required this.selectedIndex,
    required this.memberLevel,
    required this.onSelected,
  });

  @override
  State<PresetCardList> createState() => _PresetCardListState();
}

class _PresetCardListState extends State<PresetCardList> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isLocked(PresetItem preset) {
    return widget.memberLevel.value < preset.requiredLevel.value;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kPresets.length,
        itemBuilder: (ctx, i) {
          final preset = kPresets[i];
          final locked = _isLocked(preset);
          final selected = widget.selectedIndex == i;
          final color = preset.color.toColor();

          return GestureDetector(
            onTap: () => widget.onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              width: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.25),
                  width: selected ? 2.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    preset.isCustom
                        ? _buildRainbowBackground()
                        : Container(color: color),
                    if (locked)
                      Container(
                        color: Colors.black.withValues(alpha: 0.55),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          preset.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (selected && !locked)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRainbowBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: SweepGradient(
          colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
        ),
      ),
    );
  }
}
