import 'dart:math';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  final double textPadding = 20.0;
  final EditorCore core;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
  final int firstVisibleLine;
  final int lastVisibleLine;

  late final double gutterWidth;
  late final List<TextSpan> _cachedSpans;

  GutterPainter({
    required this.core,
    required this.firstVisibleLine,
    required this.lastVisibleLine,
  }) {
    final totalLines = core.lines.length;
    final width = totalLines.toString().length;
    gutterWidth = (width * core.config.characterWidth) + (textPadding * 2);

    _initializeCache(totalLines, width);
  }

  void _initializeCache(int totalLines, int width) {
    _cachedSpans = List.generate(
      totalLines,
      (i) => TextSpan(
        style: TextStyle(
          fontFamily: core.config.fontFamily,
          fontSize: core.config.fontSize,
          color: core.config.gutterTextcolor,
        ),
        text: '${(i + 1).toString().padLeft(width)}\n',
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawLines(canvas, size);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
  }

  void drawLines(Canvas canvas, Size size) {
    final start = firstVisibleLine;
    final end = min(core.lines.length, lastVisibleLine + 1);

    textPainter.text = TextSpan(
      children: _cachedSpans.sublist(start, end),
    );

    textPainter.layout(
      maxWidth: size.width,
      minWidth: 0,
    );

    final verticalOffset = (firstVisibleLine * core.config.lineHeight);

    textPainter.paint(
      canvas,
      Offset(size.width - gutterWidth + textPadding, verticalOffset),
    );
  }

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return oldDelegate.firstVisibleLine != firstVisibleLine ||
        oldDelegate.lastVisibleLine != lastVisibleLine ||
        oldDelegate.core != core;
  }
}
