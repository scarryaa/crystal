import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final String text;

  EditorPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(EditorPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
