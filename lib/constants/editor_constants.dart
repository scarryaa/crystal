import 'package:flutter/material.dart';

class EditorConstants {
  static const double horizontalPadding = 100;
  static const int verticalPaddingLines = 5;
  static double verticalPadding = lineHeight * verticalPaddingLines;
  static const double lineHeightRatio = 1.5;
  static double fontSize = 14;
  static double lineHeight = fontSize * lineHeightRatio;
  static String fontFamily = "ZedMono Nerd Font";
  static Paint currentLineHighlight = Paint()
    ..color = Colors.blue.withOpacity(0.2);
}
