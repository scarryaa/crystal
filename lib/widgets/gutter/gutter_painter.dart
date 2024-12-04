import 'dart:math';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  static const double _textPadding = 20.0;

  final EditorCore core;
  final int firstVisibleLine;
  final int lastVisibleLine;
  final double viewportHeight;

  final TextPainter _textPainter =
      TextPainter(textDirection: TextDirection.ltr);
  late final Paint _backgroundPaint;

  GutterPainter({
    required this.core,
    required this.firstVisibleLine,
    required this.lastVisibleLine,
    required this.viewportHeight,
  }) : super(repaint: core) {
    _backgroundPaint = Paint()..color = core.config.backgroundColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawLineNumbers(canvas, size);

    drawCurrentLineHighlight(canvas, size);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, viewportHeight),
      _backgroundPaint,
    );
  }

  void drawLineNumbers(Canvas canvas, Size size) {
    final start = firstVisibleLine;
    final end =
        min(core.lines.length, lastVisibleLine + core.config.lineBuffer);

    final textStyle = TextStyle(
      color: Colors.grey,
      fontSize: core.config.fontSize,
      fontFamily: core.config.fontFamily,
      fontFeatures: const [FontFeature.enable('kern')],
    );

    double maxLineNumberWidth = 0;
    for (int i = start; i < end; i++) {
      _textPainter
        ..text = TextSpan(
          text: '${i + 1}',
          style: textStyle,
        )
        ..layout(maxWidth: double.infinity);

      maxLineNumberWidth = max(maxLineNumberWidth, _textPainter.width);
    }

    final gutterWidth = maxLineNumberWidth + (_textPadding * 2);

    _textPainter
      ..text = TextSpan(
        children: List.generate(
          end - start,
          (index) => TextSpan(
              text: '${start + index + 1}\n',
              style: TextStyle(
                color: core.cursorLine == (start + index) ||
                        (start + index >= core.selectionManager.startLine &&
                            start + index <= core.selectionManager.endLine)
                    ? Colors.black
                    : Colors.grey,
                fontSize: core.config.fontSize,
                fontFamily: core.config.fontFamily,
                fontFeatures: const [FontFeature.enable('kern')],
              )),
        ),
      )
      ..layout(
        maxWidth: gutterWidth,
        minWidth: 0,
      )
      ..paint(
        canvas,
        Offset(size.width - gutterWidth + _textPadding,
            firstVisibleLine * core.config.lineHeight),
      );
  }

  void drawCurrentLineHighlight(Canvas canvas, Size size) {
    if (core.hasSelection()) return;

    canvas.drawRect(
        Rect.fromLTWH(0, core.cursorManager.cursorLine * core.config.lineHeight,
            size.width, core.config.lineHeight),
        Paint()..color = Colors.blue.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return firstVisibleLine != oldDelegate.firstVisibleLine ||
        lastVisibleLine != oldDelegate.lastVisibleLine ||
        !identical(core, oldDelegate.core) ||
        core.cursorLine != oldDelegate.core.cursorLine;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GutterPainter &&
        firstVisibleLine == other.firstVisibleLine &&
        lastVisibleLine == other.lastVisibleLine &&
        core == other.core;
  }

  @override
  int get hashCode => Object.hash(firstVisibleLine, lastVisibleLine, core);
}
