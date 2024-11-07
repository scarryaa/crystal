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

  static double fontSize = 14;
  static String fontFamily = 'IBM Plex Mono';
  static double charWidth = _textPainter.width;
  static Paint currentLineHighlight = Paint()
    ..color = Colors.blue.withOpacity(0.2);
  static Paint whitespaceIndicatorColor = Paint()
    ..color = Colors.black.withOpacity(0.5);
  static double whitespaceIndicatorRadius = 1;
  static Paint indentLineColor = Paint()..color = Colors.black.withOpacity(0.5);
}
