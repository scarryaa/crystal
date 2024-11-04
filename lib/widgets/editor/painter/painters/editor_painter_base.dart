import 'package:flutter/material.dart';

abstract class EditorPainterBase {
  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  });

  bool shouldRepaint(EditorPainterBase oldDelegate) => false;
}
