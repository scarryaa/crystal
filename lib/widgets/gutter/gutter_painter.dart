import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  final double textPadding = 20.0;
  final EditorCore core;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
  final int firstVisibleLine;
  final int lastVisibleLine;

  GutterPainter({
    required this.core,
    required this.firstVisibleLine,
    required this.lastVisibleLine,
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

    final gutterWidth =
        (width * core.config.characterWidth) + (textPadding * 2);

    textPainter.text = TextSpan(
        children: List.generate(
            min(totalLines, firstVisibleLine + lastVisibleLine),
            (i) => TextSpan(
                style: TextStyle(
                  fontFamily: core.config.fontFamily,
                  fontSize: core.config.fontSize,
                  color: core.config.gutterTextcolor,
                ),
                text: '${(i + 1).toString().padLeft(width)}\n')));

    textPainter.layout();
    textPainter.paint(
        canvas, Offset(size.width - gutterWidth + textPadding, 0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
