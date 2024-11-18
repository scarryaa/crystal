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
  final Color success;
  final Color warning;
  final Color error;
  late final Color whitespaceIndicatorColor;
  late final Color currentLineHighlight;
  late final Color indentLineColor;
  final Color indentGuideActive;
  final Color wordHoverHighlight;

  EditorTheme({
    required this.name,
    required this.primary,
    required this.background,
    required this.backgroundLight,
    required this.titleBar,
    required this.border,
    required this.text,
    required this.textLight,
    required this.success,
    required this.warning,
    required this.error,
    this.indentGuideActive = const Color(0xFF4B4B4B),
    required this.wordHoverHighlight,
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
      success: _colorFromHex(json['success'] as String? ?? '#4CAF50'),
      warning: _colorFromHex(json['warning'] as String? ?? '#FFA726'),
      error: _colorFromHex(json['error'] as String? ?? '#F44336'),
      wordHoverHighlight: _colorFromHex(json['primary'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'primary': _colorToHex(primary),
        'background': _colorToHex(background),
        'backgroundLight': _colorToHex(backgroundLight),
        'titleBar': _colorToHex(titleBar),
        'border': _colorToHex(border),
        'text': _colorToHex(text),
        'textLight': _colorToHex(textLight),
        'success': _colorToHex(success),
        'warning': _colorToHex(warning),
        'error': _colorToHex(error),
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
