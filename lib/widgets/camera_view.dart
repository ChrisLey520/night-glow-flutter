import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';

enum CaptureMode { photo, video }

class CameraView extends StatefulWidget {
  final CameraController? cameraController;
  final bool mirrorCapture;
  final VoidCallback onToggleControlPanel;
  final VoidCallback onToggleSettings;

  const CameraView({
    super.key,
    required this.cameraController,
    required this.mirrorCapture,
    required this.onToggleControlPanel,
    required this.onToggleSettings,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CaptureMode _mode = CaptureMode.photo;
  bool _delayMode = false;
  bool _isBursting = false;
  bool _isRecording = false;
  int _countdown = 0;
  int _recordSeconds = 0;
  Timer? _timer;
  int _burstCount = 0;

  void _startCountdown(VoidCallback onDone) {
    // Fix #7: cancel existing timer before creating a new one
    _timer?.cancel();
    setState(() => _countdown = 3);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _countdown = 0);
        onDone();
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  Future<void> _takeBurst() async {
    final ctrl = widget.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    // Fix #3: guard setState with mounted checks throughout async method
    if (!mounted) return;
    setState(() {
      _isBursting = true;
      _burstCount = 0;
    });
    for (int i = 0; i < 3; i++) {
      if (!mounted) break;
      try {
        final file = await ctrl.takePicture();
        await Gal.putImage(file.path);
        if (mounted) setState(() => _burstCount = i + 1);
      } catch (_) {}
      if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
    }
    if (mounted) setState(() => _isBursting = false);
  }

  Future<void> _startRecording() async {
    final ctrl = widget.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      await ctrl.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      // Fix #7: cancel existing timer before creating a new one
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('Record error: $e');
    }
  }

  Future<void> _stopRecording() async {
    final ctrl = widget.cameraController;
    // Fix #1: always reset _isRecording regardless of error path
    if (ctrl == null) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }
    _timer?.cancel();
    try {
      final file = await ctrl.stopVideoRecording();
      if (mounted) setState(() => _isRecording = false);
      await Gal.putVideo(file.path);
    } catch (e) {
      debugPrint('Stop record error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  void _onShutter() {
    if (_mode == CaptureMode.video) {
      if (_isRecording) {
        _stopRecording();
      } else {
        _startRecording();
      }
      return;
    }

    // Fix #2: ignore taps while burst or countdown is already running
    if (_isBursting || _countdown > 0) return;

    if (_delayMode) {
      _startCountdown(_takeBurst);
    } else {
      _takeBurst();
    }
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Settings button
              _iconButton(Icons.settings_outlined, widget.onToggleSettings),
              // Mode tabs
              _modeSelector(),
              // Control panel toggle
              _iconButton(Icons.tune, widget.onToggleControlPanel),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Shutter row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer toggle
            GestureDetector(
              onTap: () {
                setState(() => _delayMode = !_delayMode);
              },
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _delayMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.transparent,
                  border: Border.all(color: Colors.white38),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 22),
                    if (_delayMode)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '3',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Main shutter button
            GestureDetector(
              onTap: _onShutter,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isRecording ? 28 : 58,
                    height: _isRecording ? 28 : 58,
                    decoration: BoxDecoration(
                      color: _mode == CaptureMode.video
                          ? (_isRecording ? Colors.red : Colors.red[400])
                          : Colors.white,
                      borderRadius: _isRecording
                          ? BorderRadius.circular(6)
                          : BorderRadius.circular(29),
                    ),
                  ),
                  if (_countdown > 0)
                    Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (_isBursting)
                    Text(
                      '$_burstCount/3',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            // Record timer / burst indicator
            Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: _isRecording
                  ? Text(
                      _formatTime(_recordSeconds),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : _isBursting
                      ? Text(
                          '$_burstCount/3',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeTab('拍照', CaptureMode.photo),
          _modeTab('录像', CaptureMode.video),
        ],
      ),
    );
  }

  Widget _modeTab(String label, CaptureMode mode) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
