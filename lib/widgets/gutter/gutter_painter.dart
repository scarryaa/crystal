import 'dart:math';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  static const double _textPadding = 20.0;

  final EditorCore core;
  final int firstVisibleLine;
  final int lastVisibleLine;
  final double viewportHeight;

  late final int _lineNumberWidth;
  late final double _gutterWidth;
  late final TextStyle _lineNumberStyle;
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
    _lineNumberWidth = core.lines.length.toString().length;
    _gutterWidth =
        (_lineNumberWidth * core.config.characterWidth) + (_textPadding * 2);
    _lineNumberStyle = TextStyle(
      fontFamily: core.config.fontFamily,
      fontSize: core.config.fontSize,
      color: core.config.gutterTextcolor,
    );
  }

  TextSpan _generateLineNumberSpan(int lineNumber) {
    return TextSpan(
      style: _lineNumberStyle,
      text: '${lineNumber.toString().padLeft(_lineNumberWidth)}\n',
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, viewportHeight),
      _backgroundPaint,
    );

    // Draw line numbers
    final start = firstVisibleLine;
    final end = min(core.lines.length, lastVisibleLine + 5);

    _textPainter
      ..text = TextSpan(
        children: List.generate(
            end - start, (index) => _generateLineNumberSpan(start + index + 1)),
      )
      ..layout(
        maxWidth: size.width,
        minWidth: 0,
      )
      ..paint(
        canvas,
        Offset(size.width - _gutterWidth + _textPadding,
            firstVisibleLine * core.config.lineHeight),
      );

    drawCurrentLineHighlight(canvas, size);
  }

  void drawCurrentLineHighlight(Canvas canvas, Size size) {
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
