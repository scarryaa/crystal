import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/material.dart';

class BackgroundPainter extends EditorPainterBase {
  final Color backgroundColor;

  const BackgroundPainter(
      {this.backgroundColor = Colors.white,
      required super.editorLayoutService});

  @override
  void paint(Canvas canvas, Size size,
      {int? firstVisibleLine, int? lastVisibleLine}) {
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BackgroundPainter oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor;
  }
}
