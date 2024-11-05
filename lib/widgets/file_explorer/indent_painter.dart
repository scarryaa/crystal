import 'package:flutter/material.dart';

class IndentPainter extends CustomPainter {
  final int level;
  final Color lineColor;
  final double indentWidth;
  final double lineWidth;

  IndentPainter({
    required this.level,
    this.lineColor = const Color(0xFFE0E0E0),
    this.indentWidth = 8.0,
    this.lineWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < level; i++) {
      final x = i * indentWidth + indentWidth / 2;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(IndentPainter oldDelegate) =>
      level != oldDelegate.level ||
      lineColor != oldDelegate.lineColor ||
      indentWidth != oldDelegate.indentWidth ||
      lineWidth != oldDelegate.lineWidth;
}
