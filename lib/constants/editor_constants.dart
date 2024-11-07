import 'package:flutter/material.dart';

class EditorConstants {
  static Paint currentLineHighlight = Paint()
    ..color = Colors.blue.withOpacity(0.2);
  static Paint whitespaceIndicatorColor = Paint()
    ..color = Colors.black.withOpacity(0.5);
  static double whitespaceIndicatorRadius = 1;
  static Paint indentLineColor = Paint()..color = Colors.black.withOpacity(0.5);
}
