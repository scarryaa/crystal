import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  final double textPadding = 25.0;
  final EditorCore core;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

  GutterPainter({
    required this.core,
  });

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawLines(canvas, size);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);
  }

  void drawLines(Canvas canvas, Size size) {
    final totalLines = core.lines.length;
    final width = totalLines.toString().length;

    textPainter.text = TextSpan(
        children: List.generate(
            totalLines,
            (i) => TextSpan(
                style: TextStyle(
                  fontFamily: core.config.fontFamily,
                  fontSize: core.config.fontSize,
                  color: core.config.gutterTextcolor,
                ),
                text: '${(i + 1).toString().padLeft(width)}\n')));

    textPainter.layout();
    textPainter.paint(
        canvas,
        Offset(
            size.width - (width * core.config.characterWidth) / 2 - textPadding,
            0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
