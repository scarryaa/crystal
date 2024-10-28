import 'package:flutter/material.dart';

class EditorConstants {
  static final TextPainter _textPainter = TextPainter(
    text: TextSpan(
      text: 'A',
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static const double horizontalPadding = 100;
  static const int verticalPaddingLines = 5;
  static const double lineHeightRatio = 1.5;
  static double fontSize = 14;
  static double lineHeight = fontSize * lineHeightRatio;
  static double verticalPadding = lineHeight * verticalPaddingLines;
  static String fontFamily = "ZedMono Nerd Font";
  static double charWidth = _textPainter.width;
  static Paint currentLineHighlight = Paint()
    ..color = Colors.blue.withOpacity(0.2);
  static Paint whitespaceIndicatorColor = Paint()
    ..color = Colors.black.withOpacity(0.5);
  static double whitespaceIndicatorRadius = 1;
  static Paint indentLineColor = Paint()..color = Colors.black.withOpacity(0.5);
}
