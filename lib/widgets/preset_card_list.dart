import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/preset_data.dart';
import '../models/membership_level.dart';
import '../models/custom_image_preset.dart';
import '../repositories/custom_preset_repository.dart';

class PresetCardList extends StatefulWidget {
  final int selectedIndex;
  final MembershipLevel memberLevel;
  final String? selectedCustomPresetId;
  final List<CustomImagePreset> customPresets;
  final CustomPresetRepository repository;
  final bool isAdding;
  final ValueChanged<int> onSelected;
  final ValueChanged<CustomImagePreset> onCustomSelected;
  final ValueChanged<List<CustomImagePreset>> onCustomPresetsChanged;
  final ValueChanged<XFile> onAddImage;

  const PresetCardList({
    super.key,
    required this.selectedIndex,
    required this.memberLevel,
    required this.selectedCustomPresetId,
    required this.customPresets,
    required this.repository,
    required this.isAdding,
    required this.onSelected,
    required this.onCustomSelected,
    required this.onCustomPresetsChanged,
    required this.onAddImage,
  });

  @override
  State<PresetCardList> createState() => _PresetCardListState();
}

class _PresetCardListState extends State<PresetCardList> {
  bool _editMode = false;

  // Card width fixed at 68, spacing 8; LayoutBuilder computes columns.
  static const double _cardW = 68;
  static const double _cardH = 80;
  static const double _gap = 8;
  static const double _hPad = 16;

  bool _isLocked(PresetItem preset) =>
      widget.memberLevel.value < preset.requiredLevel.value;

  // ── Add flow ──────────────────────────────────────────────────────────────

  Future<void> _startAdd() async {
    if (widget.isAdding) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    // Delegate dialog + save to HomePage so it runs from the root context,
    // avoiding the iOS issue where showDialog from a nested widget context
    // renders only the modal barrier with no dialog content.
    widget.onAddImage(picked);
  }

  // ── Remove flow ────────────────────────────────────────────────────────────

  Future<void> _confirmRemove(CustomImagePreset preset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('移除自定义背景',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          '确定移除「${preset.name}」？此操作不可撤销，但不会影响你相册中的原始图片。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.repository.remove(preset.id);
    final updated =
        widget.customPresets.where((p) => p.id != preset.id).toList();
    widget.onCustomPresetsChanged(updated);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final availW = constraints.maxWidth - _hPad * 2;
      final cols = ((availW + _gap) / (_cardW + _gap)).floor().clamp(3, 8);
      final cellW = (availW - _gap * (cols - 1)) / cols;

      final builtInCards =
          List.generate(kPresets.length, (i) => _buildBuiltIn(i, cellW));
      final customCards = widget.customPresets
          .map((p) => _buildCustom(p, cellW))
          .toList();
      final addBtn = _buildAddButton(cellW);

      final allCards = [...builtInCards, ...customCards, addBtn];

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 10),
        child: Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: allCards,
        ),
      );
    });
  }

  Widget _buildBuiltIn(int i, double cellW) {
    final preset = kPresets[i];
    final locked = _isLocked(preset);
    final selected = widget.selectedCustomPresetId == null &&
        widget.selectedIndex == i;
    final color = preset.color.toColor();

    return GestureDetector(
      onTap: () {
        if (_editMode) {
          setState(() => _editMode = false);
          return;
        }
        _onBuiltInTap(i, preset, locked);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cellW,
        height: _cardH,
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
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(fit: StackFit.expand, children: [
            preset.isCustom
                ? _rainbowBg()
                : Container(color: color),
            if (locked)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Icon(Icons.lock,
                    color: Colors.white, size: 18),
              ),
            _nameLabel(preset.name),
            if (selected && !locked) _selectedDot(),
          ]),
        ),
      ),
    );
  }

  Widget _buildCustom(CustomImagePreset preset, double cellW) {
    final selected = widget.selectedCustomPresetId == preset.id;
    final file = File(preset.localPath);

    return GestureDetector(
      onTap: () {
        if (_editMode) {
          setState(() => _editMode = false);
          return;
        }
        widget.onCustomSelected(preset);
      },
      onLongPress: () => setState(() => _editMode = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cellW,
        height: _cardH,
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
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2)
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(fit: StackFit.expand, children: [
            Image.file(file, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image,
                        color: Colors.white38))),
            _nameLabel(preset.name),
            if (selected) _selectedDot(),
            if (_editMode) _removeButton(preset),
          ]),
        ),
      ),
    );
  }

  Widget _buildAddButton(double cellW) {
    return GestureDetector(
      onTap: _editMode
          ? () => setState(() => _editMode = false)
          : _startAdd,
      child: SizedBox(
        width: cellW,
        height: _cardH,
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: Center(
            child: widget.isAdding
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white38))
                : const Icon(Icons.add,
                    color: Colors.white38, size: 28),
          ),
        ),
      ),
    );
  }

  void _onBuiltInTap(int i, PresetItem preset, bool locked) {
    if (locked) {
      // bubble up — ControlPanel handles membership gate
      widget.onSelected(i);
      return;
    }
    widget.onSelected(i);
  }

  Widget _nameLabel(String name) => Positioned(
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
                Colors.transparent
              ],
            ),
          ),
          child: Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w500)),
        ),
      );

  Widget _selectedDot() => Positioned(
        top: 4,
        right: 4,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      );

  Widget _removeButton(CustomImagePreset preset) => Positioned(
        top: -2,
        right: -2,
        child: GestureDetector(
          onTap: () => _confirmRemove(preset),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Icon(Icons.remove,
                color: Colors.white, size: 14),
          ),
        ),
      );

  Widget _rainbowBg() => Container(
        decoration: const BoxDecoration(
          gradient: SweepGradient(colors: [
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ]),
        ),
      );
}

/// Paints a dashed rounded-rect border.
class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const r = 12.0;
    const dash = 5.0;
    const gap = 4.0;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(r)));

    final metric = path.computeMetrics().first;
    double dist = 0;
    while (dist < metric.length) {
      final end = (dist + dash).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(dist, end), paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter _) => false;
}
