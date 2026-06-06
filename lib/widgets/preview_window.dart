import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class PreviewWindow extends StatefulWidget {
  final CameraController? cameraController;
  final double initialX;
  final double initialY;
  final double initialW;
  final double initialH;
  final bool mirrorMode;
  final void Function(double x, double y, double w, double h) onLayoutChanged;

  const PreviewWindow({
    super.key,
    required this.cameraController,
    required this.initialX,
    required this.initialY,
    required this.initialW,
    required this.initialH,
    required this.mirrorMode,
    required this.onLayoutChanged,
  });

  @override
  State<PreviewWindow> createState() => _PreviewWindowState();
}

class _PreviewWindowState extends State<PreviewWindow> {
  late double _x;
  late double _y;
  late double _w;
  late double _h;

  static const double _minW = 80.0;
  static const double _minH = 80.0;
  static const double _handleSize = 16.0;

  Offset? _dragStart;
  double? _startX, _startY, _startW, _startH;
  _ResizeHandle? _activeHandle;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _x = widget.initialX;
    _y = widget.initialY;
    _w = widget.initialW;
    _h = widget.initialH;
  }

  // Fix #5: sync layout from parent when settings sliders update the values
  @override
  void didUpdateWidget(PreviewWindow old) {
    super.didUpdateWidget(old);
    if (!_isDragging &&
        (widget.initialX != old.initialX ||
            widget.initialY != old.initialY ||
            widget.initialW != old.initialW ||
            widget.initialH != old.initialH)) {
      setState(() {
        _x = widget.initialX;
        _y = widget.initialY;
        _w = widget.initialW;
        _h = widget.initialH;
      });
    }
  }

  void _saveLayout() {
    widget.onLayoutChanged(_x, _y, _w, _h);
  }

  void _clampToScreen(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    _x = _x.clamp(0.0, screen.width - _w);
    _y = _y.clamp(0.0, screen.height - _h);
    _w = _w.clamp(_minW, screen.width - _x);
    _h = _h.clamp(_minH, screen.height - _y);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _x,
      top: _y,
      child: GestureDetector(
        onPanStart: (d) {
          _isDragging = true;
          _dragStart = d.localPosition;
          _startX = _x;
          _startY = _y;
          _startW = _w;
          _startH = _h;
          _activeHandle = _detectHandle(d.localPosition);
        },
        onPanUpdate: (d) {
          if (_activeHandle == null || _activeHandle == _ResizeHandle.move) {
            setState(() {
              _x = (_startX! + d.localPosition.dx - _dragStart!.dx);
              _y = (_startY! + d.localPosition.dy - _dragStart!.dy);
              _clampToScreen(context);
            });
          } else {
            _handleResize(d.localPosition, context);
          }
        },
        onPanEnd: (_) {
          _isDragging = false;
          _saveLayout();
          _activeHandle = null;
        },
        child: SizedBox(
          width: _w,
          height: _h,
          child: Stack(
            children: [
              // Camera preview
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _buildPreview(),
                    ),
                  ),
                ),
              ),
              // Resize handles
              ..._buildHandles(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final ctrl = widget.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.camera_alt, color: Colors.white38, size: 32),
        ),
      );
    }
    Widget preview = CameraPreview(ctrl);
    if (widget.mirrorMode) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: preview,
      );
    }
    return preview;
  }

  _ResizeHandle? _detectHandle(Offset local) {
    final hs = _handleSize + 4;
    if (local.dx < hs && local.dy < hs) return _ResizeHandle.topLeft;
    if (local.dx > _w - hs && local.dy < hs) return _ResizeHandle.topRight;
    if (local.dx < hs && local.dy > _h - hs) return _ResizeHandle.bottomLeft;
    if (local.dx > _w - hs && local.dy > _h - hs) {
      return _ResizeHandle.bottomRight;
    }
    return _ResizeHandle.move;
  }

  void _handleResize(Offset current, BuildContext context) {
    final dx = current.dx - _dragStart!.dx;
    final dy = current.dy - _dragStart!.dy;

    setState(() {
      switch (_activeHandle) {
        case _ResizeHandle.topLeft:
          // Fix: when _w is clamped, sync _x so the right edge stays anchored
          _w = (_startW! - dx).clamp(_minW, double.infinity);
          _x = _startX! + (_startW! - _w);
          _h = (_startH! - dy).clamp(_minH, double.infinity);
          _y = _startY! + (_startH! - _h);
          break;
        case _ResizeHandle.topRight:
          _w = (_startW! + dx).clamp(_minW, double.infinity);
          _h = (_startH! - dy).clamp(_minH, double.infinity);
          _y = _startY! + (_startH! - _h);
          break;
        case _ResizeHandle.bottomLeft:
          // Fix: same right-edge anchor for left-side handle
          _w = (_startW! - dx).clamp(_minW, double.infinity);
          _x = _startX! + (_startW! - _w);
          _h = (_startH! + dy).clamp(_minH, double.infinity);
          break;
        case _ResizeHandle.bottomRight:
          _w = (_startW! + dx).clamp(_minW, double.infinity);
          _h = (_startH! + dy).clamp(_minH, double.infinity);
          break;
        default:
          break;
      }
      _clampToScreen(context);
    });
  }

  List<Widget> _buildHandles() {
    return [
      _handle(left: 0, top: 0),
      _handle(right: 0, top: 0),
      _handle(left: 0, bottom: 0),
      _handle(right: 0, bottom: 0),
    ];
  }

  Widget _handle({double? left, double? right, double? top, double? bottom}) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: _handleSize,
        height: _handleSize,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.only(
            topLeft: (left == 0 && top == 0) ? const Radius.circular(4) : Radius.zero,
            topRight: (right == 0 && top == 0) ? const Radius.circular(4) : Radius.zero,
            bottomLeft:
                (left == 0 && bottom == 0) ? const Radius.circular(4) : Radius.zero,
            bottomRight:
                (right == 0 && bottom == 0) ? const Radius.circular(4) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

enum _ResizeHandle { move, topLeft, topRight, bottomLeft, bottomRight }
