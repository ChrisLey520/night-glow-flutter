import 'dart:math';
import 'package:flutter/material.dart';

class ColorWheelPainter extends CustomPainter {
  final double hue;
  final double saturation;

  ColorWheelPainter({required this.hue, required this.saturation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw hue ring
    final ringWidth = radius * 0.22;
    final innerRadius = radius - ringWidth;

    for (int i = 0; i < 360; i++) {
      final startAngle = (i - 1) * pi / 180;
      final sweepAngle = 2 * pi / 180;
      final color = HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor();
      final paint = Paint()
        ..color = color
        ..strokeWidth = ringWidth + 1
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius + ringWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Draw saturation disc (inside the ring)
    final discRadius = innerRadius - 4;
    final rect = Rect.fromCircle(center: center, radius: discRadius);
    final shader = RadialGradient(
      colors: [
        Colors.white,
        HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
      ],
    ).createShader(rect);
    final discPaint = Paint()..shader = shader;
    canvas.drawCircle(center, discRadius, discPaint);

    // Darken overlay for brightness-like feel (reserved for future use)

    // Hue indicator on ring
    final hueAngle = (hue - 90) * pi / 180;
    final indicatorR = innerRadius + ringWidth / 2;
    final ix = center.dx + indicatorR * cos(hueAngle);
    final iy = center.dy + indicatorR * sin(hueAngle);
    canvas.drawCircle(
      Offset(ix, iy),
      ringWidth / 2 + 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      Offset(ix, iy),
      ringWidth / 2 - 1,
      Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
    );

    // Saturation indicator inside disc
    final satX = center.dx + (saturation - 0.5) * 2 * discRadius * 0.7;
    final satY = center.dy;
    canvas.drawCircle(
      Offset(satX, satY),
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      Offset(satX, satY),
      8,
      Paint()
        ..color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor(),
    );
  }

  @override
  bool shouldRepaint(ColorWheelPainter old) =>
      old.hue != hue || old.saturation != saturation;
}

class ColorWheel extends StatefulWidget {
  final double hue;
  final double saturation;
  final ValueChanged<double> onHueChanged;
  final ValueChanged<double> onSaturationChanged;

  const ColorWheel({
    super.key,
    required this.hue,
    required this.saturation,
    required this.onHueChanged,
    required this.onSaturationChanged,
  });

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  late double _hue;
  late double _saturation;

  @override
  void initState() {
    super.initState();
    _hue = widget.hue;
    _saturation = widget.saturation;
  }

  @override
  void didUpdateWidget(ColorWheel old) {
    super.didUpdateWidget(old);
    _hue = widget.hue;
    _saturation = widget.saturation;
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final ringWidth = radius * 0.22;
    final innerRadius = radius - ringWidth;
    final local = details.localPosition;
    final dx = local.dx - center.dx;
    final dy = local.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);

    if (dist >= innerRadius - 4) {
      double angle = atan2(dy, dx) * 180 / pi + 90;
      if (angle < 0) angle += 360;
      if (angle >= 360) angle -= 360;
      // Fix #9: skip local setState — parent callback triggers parent rebuild
      // which propagates new hue back via didUpdateWidget, avoiding double repaint
      _hue = angle;
      widget.onHueChanged(angle);
    } else {
      final discRadius = innerRadius - 4;
      final relX = dx / (discRadius * 0.7 * 2) + 0.5;
      final sat = relX.clamp(0.0, 1.0);
      // Fix #9: same — let parent drive the repaint
      _saturation = sat;
      widget.onSaturationChanged(sat);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: (d) => _handlePanUpdate(d, size),
          child: CustomPaint(
            painter: ColorWheelPainter(hue: _hue, saturation: _saturation),
            size: size,
          ),
        );
      },
    );
  }
}
