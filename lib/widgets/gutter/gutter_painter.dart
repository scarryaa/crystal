import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/cursor.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  final int lineCount;
  final Cursor cursor;

  final TextStyle _defaultStyle;
  final TextStyle _highlightStyle;

  GutterPainter({
    required this.lineCount,
    required this.cursor,
    Color? textColor,
    Color? highlightColor,
  })  : _defaultStyle = TextStyle(
          color: textColor ?? Colors.grey[600],
          fontSize: EditorConstants.fontSize,
          fontFamily: EditorConstants.fontFamily,
        ),
        _highlightStyle = TextStyle(
          color: highlightColor ?? Colors.blue,
          fontSize: EditorConstants.fontSize,
          fontFamily: EditorConstants.fontFamily,
        );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var i = 0; i < lineCount; i++) {
      final lineNumber = (i + 1).toString();
      final style = cursor.line == i ? _highlightStyle : _defaultStyle;

      textPainter.text = TextSpan(
        text: lineNumber,
        style: style,
      );

      textPainter.layout();

      final xOffset = size.width / 2 - textPainter.width;
      final yOffset = i * EditorConstants.lineHeight +
          (EditorConstants.lineHeight - textPainter.height) / 2;

      textPainter.paint(
        canvas,
        Offset(xOffset, yOffset),
      );
    }
  }

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return lineCount != oldDelegate.lineCount || cursor != oldDelegate.cursor;
  }
}
