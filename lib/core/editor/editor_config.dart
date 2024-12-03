import 'package:flutter/material.dart';

class EditorConfig {
  double fontSize;
  late double lineHeight;
  String fontFamily;
  Color textColor;
  double cursorWidth;

  EditorConfig({
    this.fontSize = 14,
    this.fontFamily = "IBM Plex Mono",
    this.textColor = Colors.black,
    this.cursorWidth = 2,
  }) {
    lineHeight = _measureLineHeight();
  }

  double _measureLineHeight() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: "Ay",
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.height;
  }
}
