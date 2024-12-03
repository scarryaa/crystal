import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter with ChangeNotifier {
  final EditorCore core;
  final EditorConfig config;
  final Color backgroundColor;
  late final TextStyle textStyle;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

  EditorPainter({
    required this.core,
    required this.config,
    this.backgroundColor = Colors.white,
  }) : super(repaint: core) {
    textStyle = TextStyle(
      color: Colors.black,
      fontSize: config.fontSize,
      fontFamily: config.fontFamily,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawText(canvas);
    drawCursor(canvas);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );
  }

  void drawText(Canvas canvas) {
    textPainter.text = TextSpan(text: core.toString(), style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }

  void drawCursor(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(_measureLineWidth(), core.cursorLine * config.lineHeight, 2,
          config.lineHeight),
      Paint()..color = Colors.blue,
    );
  }

  double _measureCharWidth() {
    textPainter.text = TextSpan(text: 'w', style: textStyle);
    textPainter.layout();
    return textPainter.width;
  }

  double _measureLineWidth() {
    return core.lines[core.cursorLine].length * _measureCharWidth();
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.core.lines != core.lines ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.textStyle != textStyle;
  }
}
