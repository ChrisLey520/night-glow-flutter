import 'package:flutter/material.dart';

class ColorModel {
  final double hue;        // 0–360
  final double saturation; // 0–1
  final double brightness; // 0–1

  const ColorModel({
    required this.hue,
    required this.saturation,
    required this.brightness,
  });

  Color toColor() {
    return HSVColor.fromAHSV(1.0, hue, saturation, brightness).toColor();
  }

  static ColorModel fromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    return ColorModel(
      hue: hsv.hue,
      saturation: hsv.saturation,
      brightness: hsv.value,
    );
  }

  ColorModel copyWith({double? hue, double? saturation, double? brightness}) {
    return ColorModel(
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      brightness: brightness ?? this.brightness,
    );
  }

  Map<String, dynamic> toJson() => {
    'hue': hue,
    'saturation': saturation,
    'brightness': brightness,
  };

  factory ColorModel.fromJson(Map<String, dynamic> json) => ColorModel(
    hue: (json['hue'] as num).toDouble(),
    saturation: (json['saturation'] as num).toDouble(),
    brightness: (json['brightness'] as num).toDouble(),
  );
}
