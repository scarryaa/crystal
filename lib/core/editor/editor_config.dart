import 'package:flutter/material.dart';

class EditorConfig {
  late double widthPadding;
  late double heightPadding;
  double fontSize;
  FontWeight fontWeight;
  late double lineHeight;
  late double characterWidth;
  double minGutterWidth;
  String fontFamily;
  Color backgroundColor;
  Color textColor;
  Color gutterTextcolor;
  Color caretColor;
  double caretRadius;
  double selectionRadius;
  late Color selectionColor;
  double caretWidth;
  int lineBuffer;
  final TextDirection? textDirection;

  EditorConfig({
    this.fontSize = 15,
    this.fontWeight = FontWeight.w400,
    this.minGutterWidth = 60,
    this.fontFamily = "IBM Plex Mono",
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF2F3337),
    this.gutterTextcolor = Colors.grey,
    this.caretColor = Colors.blue,
    this.caretRadius = 2.0,
    this.selectionRadius = 2.0,
    this.caretWidth = 2,
    this.lineBuffer = 5,
    this.textDirection,
  }) {
    lineHeight = _measureLineHeight();
    characterWidth = _measureCharacterWidth();
    selectionColor = Colors.blue.withOpacity(0.3);

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
