import 'package:flutter/material.dart';

class EditorTheme {
  final String name;
  final Color primary;
  final Color background;
  final Color backgroundLight;
  final Color border;
  final Color text;
  final Color textLight;
  final Color titleBar;
  late final Color whitespaceIndicatorColor;
  late final Color currentLineHighlight;
  late final Color indentLineColor;

  EditorTheme({
    required this.name,
    required this.primary,
    required this.background,
    required this.backgroundLight,
    required this.titleBar,
    required this.border,
    required this.text,
    required this.textLight,
  }) {
    whitespaceIndicatorColor = text.withOpacity(0.5);
    currentLineHighlight = primary.withOpacity(0.1);
    indentLineColor = text.withOpacity(0.2);
  }

  factory EditorTheme.fromJson(Map<String, dynamic> json) {
    return EditorTheme(
      name: json['name'] as String,
      primary: _colorFromHex(json['primary'] as String),
      background: _colorFromHex(json['background'] as String),
      backgroundLight: _colorFromHex(json['backgroundLight'] as String),
      titleBar: _colorFromHex(json['titleBar'] as String),
      border: _colorFromHex(json['border'] as String),
      text: _colorFromHex(json['text'] as String),
      textLight: _colorFromHex(json['textLight'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'primary': _colorToHex(primary),
        'background': _colorToHex(background),
        'text': _colorToHex(text),
      };

  static Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String _colorToHex(Color color) =>
      '#${color.value.toRadixString(16).substring(2)}';
}
