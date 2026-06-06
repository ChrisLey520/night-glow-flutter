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
    return HSVColor.fromAHSV(
      1.0,
      hue.clamp(0.0, 359.9),
      saturation.clamp(0.0, 1.0),
      brightness.clamp(0.0, 1.0),
    ).toColor();
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

  factory ColorModel.fromJson(Map<String, dynamic> json) {
    // Fix: clamp values from persisted data to prevent HSVColor assert crashes
    // if storage was corrupted or written by a different app version.
    final hue = (json['hue'] as num).toDouble().clamp(0.0, 359.9);
    final sat = (json['saturation'] as num).toDouble().clamp(0.0, 1.0);
    final bri = (json['brightness'] as num).toDouble().clamp(0.0, 1.0);
    return ColorModel(hue: hue, saturation: sat, brightness: bri);
  }
}
