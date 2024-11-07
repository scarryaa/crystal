import 'package:flutter/material.dart';

class EditorTheme {
  final String name;
  final Color primary;
  final Color background;
  final Color text;
  late final Color whitespaceIndicatorColor;

  EditorTheme({
    required this.name,
    required this.primary,
    required this.background,
    required this.text,
  }) {
    whitespaceIndicatorColor = text.withOpacity(0.5);
  }

  factory EditorTheme.fromJson(Map<String, dynamic> json) {
    return EditorTheme(
      name: json['name'] as String,
      primary: _colorFromHex(json['primary'] as String),
      background: _colorFromHex(json['background'] as String),
      text: _colorFromHex(json['text'] as String),
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
