import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class PreviewWindow extends StatefulWidget {
  final CameraController? cameraController;
  final double initialX;
  final double initialY;
  final double initialW;
  final double initialH;
  final bool mirrorMode;
  final bool ignoring;
  final void Function(double x, double y, double w, double h) onLayoutChanged;

  const PreviewWindow({
    super.key,
    required this.cameraController,
    required this.initialX,
    required this.initialY,
    required this.initialW,
    required this.initialH,
    required this.mirrorMode,
    this.ignoring = false,
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

  Offset? _dragStartGlobal;
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

  // Sync layout from parent when settings sliders update the values.
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
    // Positioned must be a direct child of Stack — IgnorePointer goes inside,
    // not outside, so the Stack can correctly read StackParentData.
    return Positioned(
      left: _x,
      top: _y,
      child: IgnorePointer(
        ignoring: widget.ignoring,
        child: GestureDetector(
          onPanStart: (d) {
            _isDragging = true;
            _dragStartGlobal = d.globalPosition;
            _startX = _x;
            _startY = _y;
            _startW = _w;
            _startH = _h;
            _activeHandle = _detectHandle(d.localPosition);
          },
          onPanUpdate: (d) {
            // Use globalPosition so the delta is stable even as the widget moves.
            final dx = d.globalPosition.dx - _dragStartGlobal!.dx;
            final dy = d.globalPosition.dy - _dragStartGlobal!.dy;
            if (_activeHandle == null || _activeHandle == _ResizeHandle.move) {
              setState(() {
                _x = _startX! + dx;
                _y = _startY! + dy;
                _clampToScreen(context);
              });
            } else {
              _handleResize(dx, dy, context);
            }
          },
          onPanEnd: (_) {
            _isDragging = false;
            _saveLayout();
            _activeHandle = null;
            _dragStartGlobal = null;
          },
          child: SizedBox(
            width: _w,
            height: _h,
            child: Stack(
              children: [
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
                ..._buildHandles(),
              ],
            ),
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

  void _handleResize(double dx, double dy, BuildContext context) {
    setState(() {
      switch (_activeHandle) {
        case _ResizeHandle.topLeft:
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
    const double lineLen = 14.0;
    const double lineW = 3.0;
    final color = Colors.white.withValues(alpha: 0.9);

    final isLeft = left != null;
    final isTop = top != null;

    return Positioned(
      left: left != null ? left - lineW / 2 : null,
      right: right != null ? right - lineW / 2 : null,
      top: top != null ? top - lineW / 2 : null,
      bottom: bottom != null ? bottom - lineW / 2 : null,
      child: SizedBox(
        width: lineLen + lineW,
        height: lineLen + lineW,
        child: CustomPaint(
          painter: _CornerHandlePainter(
            color: color,
            lineLen: lineLen,
            lineW: lineW,
            isLeft: isLeft,
            isTop: isTop,
          ),
        ),
      ),
    );
  }
}

enum _ResizeHandle { move, topLeft, topRight, bottomLeft, bottomRight }

class _CornerHandlePainter extends CustomPainter {
  final Color color;
  final double lineLen;
  final double lineW;
  final bool isLeft;
  final bool isTop;

  const _CornerHandlePainter({
    required this.color,
    required this.lineLen,
    required this.lineW,
    required this.isLeft,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineW
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final double x = isLeft ? lineW / 2 : size.width - lineW / 2;
    final double y = isTop ? lineW / 2 : size.height - lineW / 2;
    final double hEnd = isLeft ? lineLen : size.width - lineLen;
    final double vEnd = isTop ? lineLen : size.height - lineLen;

    canvas.drawLine(Offset(x, y), Offset(hEnd, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, vEnd), paint);
  }

  @override
  bool shouldRepaint(_CornerHandlePainter old) =>
      old.color != color ||
      old.lineLen != lineLen ||
      old.lineW != lineW ||
      old.isLeft != isLeft ||
      old.isTop != isTop;
}
