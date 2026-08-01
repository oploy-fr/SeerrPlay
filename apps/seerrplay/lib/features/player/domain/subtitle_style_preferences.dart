import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubtitleSize {
  small('Small', 0.82),
  medium('Medium', 1),
  large('Large', 1.24);

  const SubtitleSize(this.label, this.scale);

  final String label;
  final double scale;
}

enum SubtitleColor {
  white('White', Color(0xFFFFFFFF)),
  yellow('Yellow', Color(0xFFFFE66D)),
  cyan('Cyan', Color(0xFF8BE9FD));

  const SubtitleColor(this.label, this.color);

  final String label;
  final Color color;
}

enum SubtitleBackground {
  none('None', Color(0x00000000)),
  subtle('Subtle', Color(0x99000000)),
  solid('Solid', Color(0xE6000000));

  const SubtitleBackground(this.label, this.color);

  final String label;
  final Color color;
}

class SubtitleStylePreferences {
  const SubtitleStylePreferences({
    this.size = SubtitleSize.medium,
    this.color = SubtitleColor.white,
    this.background = SubtitleBackground.subtle,
  });

  static const _sizeKey = 'player_subtitle_size_v1';
  static const _colorKey = 'player_subtitle_color_v1';
  static const _backgroundKey = 'player_subtitle_background_v1';

  final SubtitleSize size;
  final SubtitleColor color;
  final SubtitleBackground background;

  SubtitleStylePreferences copyWith({
    SubtitleSize? size,
    SubtitleColor? color,
    SubtitleBackground? background,
  }) => SubtitleStylePreferences(
    size: size ?? this.size,
    color: color ?? this.color,
    background: background ?? this.background,
  );

  static Future<SubtitleStylePreferences> load() async {
    final preferences = await SharedPreferences.getInstance();
    return SubtitleStylePreferences(
      size: _enumValue(
        SubtitleSize.values,
        preferences.getString(_sizeKey),
        SubtitleSize.medium,
      ),
      color: _enumValue(
        SubtitleColor.values,
        preferences.getString(_colorKey),
        SubtitleColor.white,
      ),
      background: _enumValue(
        SubtitleBackground.values,
        preferences.getString(_backgroundKey),
        SubtitleBackground.subtle,
      ),
    );
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_sizeKey, size.name),
      preferences.setString(_colorKey, color.name),
      preferences.setString(_backgroundKey, background.name),
    ]);
  }
}

T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.where((value) => value.name == name).firstOrNull ?? fallback;
