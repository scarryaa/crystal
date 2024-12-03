import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter with ChangeNotifier {
  final EditorCore core;
  late final TextStyle textStyle;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

  EditorPainter({
    required this.core,
  }) : super(repaint: core) {
    textStyle = TextStyle(
      color: core.config.textColor,
      fontSize: core.config.fontSize,
      fontFamily: core.config.fontFamily,
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
      Paint()..color = core.config.backgroundColor,
    );
  }

  void drawText(Canvas canvas) {
    textPainter.text = TextSpan(text: core.toString(), style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }

  void drawCursor(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(_measureLineWidth(),
          core.cursorLine * core.config.lineHeight, 2, core.config.lineHeight),
      Paint()..color = core.config.caretColor,
    );
  }

  double _measureCharWidth() {
    textPainter.text = TextSpan(text: 'w', style: textStyle);
    textPainter.layout();
    return textPainter.width;
  }

  double _measureLineWidth() {
    return core.cursorPosition * _measureCharWidth();
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.core.lines != core.lines ||
        oldDelegate.core.config != core.config ||
        oldDelegate.textStyle != textStyle;
  }
}
