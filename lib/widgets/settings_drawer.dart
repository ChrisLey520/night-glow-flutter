import 'package:flutter/material.dart';
import '../models/membership_level.dart';

class SettingsDrawer extends StatefulWidget {
  final MembershipLevel memberLevel;
  final bool mirrorCapture;
  final double previewX;
  final double previewY;
  final double previewW;
  final double previewH;
  final VoidCallback onClose;
  final ValueChanged<bool> onMirrorChanged;
  final void Function(double x, double y, double w, double h) onPreviewLayoutChanged;
  final VoidCallback onMembershipUpgrade;

  const SettingsDrawer({
    super.key,
    required this.memberLevel,
    required this.mirrorCapture,
    required this.previewX,
    required this.previewY,
    required this.previewW,
    required this.previewH,
    required this.onClose,
    required this.onMirrorChanged,
    required this.onPreviewLayoutChanged,
    required this.onMembershipUpgrade,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  int _expandedSection = -1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() {
    _ctrl.reverse().then((_) => widget.onClose());
  }

  String _levelName(MembershipLevel level) {
    switch (level) {
      case MembershipLevel.svip:
        return 'SVIP';
      case MembershipLevel.vip:
        return 'VIP';
      default:
        return '免费版';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: _close,
          child: Container(color: Colors.transparent),
        ),
        // Drawer
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                border: Border(
                  left: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          const Text(
                            '设置',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: _close,
                            icon: const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _section(
                            index: 0,
                            icon: Icons.workspace_premium,
                            title: '会员',
                            subtitle: _levelName(widget.memberLevel),
                            child: _membershipSection(),
                          ),
                          _section(
                            index: 1,
                            icon: Icons.flip,
                            title: '镜像拍摄',
                            trailing: Switch(
                              value: widget.mirrorCapture,
                              onChanged: widget.onMirrorChanged,
                              activeThumbColor: Colors.white,
                              activeTrackColor: Colors.blue,
                              inactiveThumbColor: Colors.white54,
                              inactiveTrackColor: Colors.white24,
                            ),
                          ),
                          _section(
                            index: 2,
                            icon: Icons.crop_free,
                            title: '预览窗口',
                            child: _previewSection(),
                          ),
                          _section(
                            index: 3,
                            icon: Icons.chat_bubble_outline,
                            title: '反馈',
                            child: _feedbackSection(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section({
    required int index,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? child,
    Widget? trailing,
  }) {
    final expanded = _expandedSection == index;
    return Column(
      children: [
        InkWell(
          onTap: child != null
              ? () => setState(
                    () => _expandedSection = expanded ? -1 : index,
                  )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
                if (child != null)
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
        if (child != null && expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: child,
          ),
        const Divider(color: Colors.white12, height: 1),
      ],
    );
  }

  Widget _membershipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _memberTier(
          '免费版',
          '· 柔白光预设\n· 广告支持',
          widget.memberLevel == MembershipLevel.normal,
        ),
        const SizedBox(height: 8),
        _memberTier(
          'VIP ¥1/年',
          '· 全部9个预设\n· 无广告',
          widget.memberLevel == MembershipLevel.vip,
        ),
        const SizedBox(height: 8),
        _memberTier(
          'SVIP ¥2/年',
          '· 全部预设\n· 自定义色轮\n· 无广告',
          widget.memberLevel == MembershipLevel.svip,
        ),
        const SizedBox(height: 12),
        if (widget.memberLevel != MembershipLevel.svip)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onMembershipUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '升级会员',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _memberTier(String title, String desc, bool active) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: active
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: active
              ? Colors.amber.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: active ? Colors.amber : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          if (active)
            const Icon(Icons.check_circle, color: Colors.amber, size: 18),
        ],
      ),
    );
  }

  Widget _previewSection() {
    return Column(
      children: [
        _sliderRow('宽度', widget.previewW, 80, 240, (v) {
          widget.onPreviewLayoutChanged(
            widget.previewX,
            widget.previewY,
            v,
            widget.previewH,
          );
        }),
        _sliderRow('高度', widget.previewH, 80, 320, (v) {
          widget.onPreviewLayoutChanged(
            widget.previewX,
            widget.previewY,
            widget.previewW,
            v,
          );
        }),
        _sliderRow('水平位置', widget.previewX, 0, 300, (v) {
          widget.onPreviewLayoutChanged(
            v,
            widget.previewY,
            widget.previewW,
            widget.previewH,
          );
        }),
        _sliderRow('垂直位置', widget.previewY, 0, 600, (v) {
          widget.onPreviewLayoutChanged(
            widget.previewX,
            v,
            widget.previewW,
            widget.previewH,
          );
        }),
      ],
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              value.toInt().toString(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Column(
        children: [
          const Icon(Icons.group, color: Colors.white54, size: 40),
          const SizedBox(height: 8),
          const Text(
            '加入反馈群',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            '扫描二维码加入用户交流群',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
