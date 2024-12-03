import 'package:crystal/core/editor_core.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter with ChangeNotifier {
  final EditorCore core;
  final Color backgroundColor;
  final TextStyle textStyle;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

  EditorPainter(
      {required this.core,
      this.backgroundColor = Colors.white,
      this.textStyle = const TextStyle(
          color: Colors.black, fontSize: 14, fontFamily: 'IBM Plex Mono')})
      : super(repaint: core);

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawText(canvas);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = backgroundColor);
  }

  void drawText(Canvas canvas) {
    textPainter.text = TextSpan(text: core.toString(), style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.core.lines != core.lines ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.textStyle != textStyle;
  }
}
