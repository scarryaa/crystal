import 'package:flutter/material.dart';

class EditorConfig {
  late double widthPadding;
  late double heightPadding;
  double fontSize;
  late double lineHeight;
  late double characterWidth;
  double minGutterWidth;
  String fontFamily;
  Color backgroundColor;
  Color textColor;
  Color gutterTextcolor;
  Color caretColor;
  double caretWidth;

  EditorConfig({
    this.fontSize = 14,
    this.minGutterWidth = 60,
    this.fontFamily = "IBM Plex Mono",
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black,
    this.gutterTextcolor = Colors.grey,
    this.caretColor = Colors.blue,
    this.caretWidth = 2,
  }) {
    lineHeight = _measureLineHeight();
    characterWidth = _measureCharacterWidth();

    widthPadding = characterWidth * 12;
    heightPadding = lineHeight * 6;
  }

  double _measureCharacterWidth() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: "y",
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.width;
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
