import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';

class CameraView extends StatefulWidget {
  final CameraController? cameraController;
  final bool mirrorCapture;
  final double fillSaturation;
  final bool motionPhoto;
  final bool isVideoMode;
  final bool isRecording;
  final String lastPhotoPath;
  final VoidCallback onToggleControlPanel;
  final VoidCallback onOpenAlbum;
  final void Function(bool) onMotionPhotoChange;
  final VoidCallback onToggleMode;
  final VoidCallback onStartVideo;
  final VoidCallback onStopVideo;

  const CameraView({
    super.key,
    required this.cameraController,
    required this.mirrorCapture,
    this.fillSaturation = 0.0,
    this.motionPhoto = false,
    required this.isVideoMode,
    required this.isRecording,
    this.lastPhotoPath = '',
    required this.onToggleControlPanel,
    required this.onOpenAlbum,
    required this.onMotionPhotoChange,
    required this.onToggleMode,
    required this.onStartVideo,
    required this.onStopVideo,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  bool _isBursting = false;
  int _countdown = 0;
  int _recordSeconds = 0;
  Timer? _timer;
  int _burstLeft = 0;
  int _delayMode = 0; // 0 | 3 | 5 | 8
  int _burstMode = 1; // 1 | 3

  Color get _btnColor =>
      widget.fillSaturation < 0.08 ? const Color(0xFF444444) : Colors.white;

  Color get _btnDimColor => widget.fillSaturation < 0.08
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.white.withValues(alpha: 0.35);

  @override
  void didUpdateWidget(CameraView old) {
    super.didUpdateWidget(old);
    // 开始录制时启动计时器
    if (widget.isRecording && !old.isRecording) {
      _recordSeconds = 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    }
    // 停止录制时清除计时器
    if (!widget.isRecording && old.isRecording) {
      _timer?.cancel();
      _timer = null;
      if (mounted) setState(() => _recordSeconds = 0);
    }
  }

  void _startCapture() {
    if (_countdown > 0 || _isBursting) return;
    if (_delayMode == 0) {
      _doCapture();
      return;
    }
    setState(() => _countdown = _delayMode);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _countdown = 0);
        _doCapture();
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  void _doCapture() {
    if (_burstMode == 3) {
      _runBurst(3);
    } else {
      _takeSingle();
    }
  }

  Future<void> _takeSingle() async {
    final ctrl = widget.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      final file = await ctrl.takePicture();
      await Gal.putImage(file.path);
    } catch (e) {
      debugPrint('take picture error: $e');
    }
  }

  Future<void> _runBurst(int total) async {
    final ctrl = widget.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (!mounted) return;
    setState(() {
      _isBursting = true;
      _burstLeft = total;
    });
    for (int i = 0; i < total; i++) {
      if (!mounted) break;
      try {
        final file = await ctrl.takePicture();
        await Gal.putImage(file.path);
        if (mounted) setState(() => _burstLeft = total - i - 1);
      } catch (_) {}
      if (i < total - 1) {
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
    if (mounted) setState(() => _isBursting = false);
  }

  void _onShutter() {
    if (widget.isVideoMode) {
      if (widget.isRecording) {
        widget.onStopVideo();
      } else {
        widget.onStartVideo();
      }
      return;
    }
    _startCapture();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.6, 1.0],
          colors: [
            Colors.transparent,
            Colors.transparent,
            widget.fillSaturation < 0.08
                ? Colors.grey.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionsRow(),
          const SizedBox(height: 4),
          _buildMainRow(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOptionsRow() {
    if (widget.isVideoMode) {
      return SizedBox(
        height: 44,
        child: Center(
          child: widget.isRecording
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_recordSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          for (final d in [0, 3, 5, 8])
            GestureDetector(
              onTap: () => setState(() => _delayMode = d),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  d == 0 ? '即拍' : '${d}s',
                  style: TextStyle(
                    fontSize: 15,
                    color: _delayMode == d ? Colors.white : Colors.white38,
                    fontWeight:
                        _delayMode == d ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          const Spacer(),
          for (final b in [1, 3])
            GestureDetector(
              onTap: () => setState(() => _burstMode = b),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  b == 1 ? '单拍' : '3连拍',
                  style: TextStyle(
                    fontSize: 15,
                    color: _burstMode == b ? Colors.white : Colors.white38,
                    fontWeight:
                        _burstMode == b ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          _circleIconButton(
            icon: Icons.palette_outlined,
            size: 52,
            onTap: widget.onToggleControlPanel,
          ),

          const Spacer(),

          SizedBox(
            width: 44,
            height: 44,
            child: !widget.isVideoMode
                ? GestureDetector(
                    onTap: () =>
                        widget.onMotionPhotoChange(!widget.motionPhoto),
                    child: Center(
                      child: Icon(
                        widget.motionPhoto
                            ? Icons.motion_photos_on
                            : Icons.motion_photos_off_outlined,
                        color: widget.motionPhoto
                            ? const Color(0xFF4CAF50)
                            : _btnColor,
                        size: 24,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const Spacer(),

          _buildShutter(),

          const Spacer(),

          // 模式切换（录制中禁用，对齐 HOS）
          SizedBox(
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: widget.isRecording ? null : widget.onToggleMode,
              child: Opacity(
                opacity: widget.isRecording ? 0.35 : 1.0,
                child: Center(
                  child: Icon(
                    widget.isVideoMode
                        ? Icons.camera_alt_outlined
                        : Icons.videocam_outlined,
                    color: _btnColor,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          _buildAlbumOrCountdown(),
        ],
      ),
    );
  }

  Widget _buildShutter() {
    // Single stable widget tree — no conditional branches that cause element
    // unmount/remount and produce a dirty render frame during mode switch.
    final isVideo = widget.isVideoMode;
    final isRec = widget.isRecording;

    // Inner shape morphs: photo → white circle 60px; video idle → red circle
    // 58px; video recording → red rounded-rect 30px.
    final innerSize = isVideo ? (isRec ? 30.0 : 58.0) : 60.0;
    final innerColor = isVideo ? const Color(0xFFFF3B30) : (_countdown > 0 ? _btnDimColor : _btnColor);
    final innerRadius = isVideo ? (isRec ? 6.0 : 29.0) : 30.0;

    return GestureDetector(
      onTap: _onShutter,
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring — always present
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _btnColor, width: 3),
              ),
            ),
            // Inner shape — morphs between photo disc and video circle/square
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                color: innerColor,
                borderRadius: BorderRadius.circular(innerRadius),
              ),
            ),
            // Burst count label (photo mode only)
            if (_isBursting)
              Text(
                '$_burstLeft',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.fillSaturation < 0.08
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumOrCountdown() {
    if (!widget.isVideoMode && _countdown > 0) {
      return SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Text(
            '$_countdown',
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onOpenAlbum,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.28),
              ),
            ),
            if (widget.lastPhotoPath.isNotEmpty && _isImagePath(widget.lastPhotoPath))
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(widget.lastPhotoPath),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => _albumIconWidget(),
                ),
              )
            else if (widget.lastPhotoPath.isNotEmpty)
              // Video thumbnail — just show a play icon
              SizedBox(
                width: 52,
                height: 52,
                child: Center(
                  child: Icon(Icons.videocam, color: _btnColor, size: 26),
                ),
              )
            else
              _albumIconWidget(),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _albumIconWidget() {
    return SizedBox(
      width: 52,
      height: 52,
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          color: Colors.white.withValues(alpha: 0.85),
          size: 26,
        ),
      ),
    );
  }

  bool _isImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'gif', 'bmp']
        .contains(ext);
  }

  Widget _circleIconButton({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.28),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
