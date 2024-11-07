import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/material.dart';

class CaretPainter extends EditorPainterBase {
  CaretPainter(this.editorState, {required super.editorLayoutService});

  final EditorState editorState;
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  @override
  void paint(Canvas canvas, Size size,
      {required int firstVisibleLine, required int lastVisibleLine}) {
    if (!editorState.showCaret) return;

    final line = editorState.buffer.getLine(editorState.cursor.line);
    final textUpToCaret = line.substring(0, editorState.cursor.column);

    _textPainter.text = TextSpan(
      text: textUpToCaret,
      style: TextStyle(
        fontSize: EditorConstants.fontSize,
        fontFamily: EditorConstants.fontFamily,
        color: Colors.black,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
        fontFeatures: const [
          FontFeature.enable('kern'),
          FontFeature.enable('liga'),
          FontFeature.enable('calt'),
        ],
        fontVariations: const [
          FontVariation('wght', 400),
        ],
      ),
    );

    _textPainter.layout();

    final caretLeft = _textPainter.width;
    final caretTop =
        editorLayoutService.config.lineHeight * editorState.cursor.line;
    final caretPaint = Paint()..color = Colors.blue;

    _drawCaret(
      canvas,
      caretLeft,
      caretTop,
      editorState.cursorShape,
      caretPaint,
    );
  }

  void _drawCaret(
    Canvas canvas,
    double left,
    double top,
    CursorShape cursorShape,
    Paint paint,
  ) {
    switch (cursorShape) {
      case CursorShape.bar:
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top,
            2.0,
            editorLayoutService.config.lineHeight,
          ),
          paint,
        );
        break;

      case CursorShape.block:
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top,
            EditorConstants.charWidth,
            editorLayoutService.config.lineHeight,
          ),
          paint,
        );
        break;

      case CursorShape.hollow:
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top,
            EditorConstants.charWidth,
            editorLayoutService.config.lineHeight,
          ),
          paint..style = PaintingStyle.stroke,
        );
        break;

      case CursorShape.underline:
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top + editorLayoutService.config.lineHeight - 2,
            EditorConstants.charWidth,
            2,
          ),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CaretPainter oldPainter) {
    return oldPainter.editorState.showCaret != editorState.showCaret ||
        oldPainter.editorState.cursor != editorState.cursor ||
        oldPainter.editorState.cursorShape != editorState.cursorShape ||
        oldPainter.editorState.buffer.getLine(editorState.cursor.line) !=
            editorState.buffer.getLine(editorState.cursor.line);
  }

  void dispose() {
    _textPainter.dispose();
  }
}
