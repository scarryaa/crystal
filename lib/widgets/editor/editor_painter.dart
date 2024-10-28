import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final EditorState editorState;
  final TextPainter _textPainter;

  EditorPainter({required this.editorState})
      : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        ),
        super(repaint: editorState);

  static double measureLineWidth(String line) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: EditorConstants.fontFamily,
          fontSize: EditorConstants.fontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Calculate visible lines
    int firstVisibleLine = max(
        0,
        (editorState.scrollState.verticalOffset / EditorConstants.lineHeight)
                .floor() -
            5);
    int lastVisibleLine = min(
        editorState.lines.length,
        ((editorState.scrollState.verticalOffset + size.height) /
                    EditorConstants.lineHeight)
                .ceil() +
            5);

    List<String> lines = editorState.lines;
    lastVisibleLine = lastVisibleLine.clamp(0, lines.length);

    // Draw visible text lines
    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (i >= 0 && i < lines.length) {
        _textPainter.text = TextSpan(
          text: lines[i],
          style: TextStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            color: Colors.black,
          ),
        );

        _textPainter.layout();

        double yPosition = (i * EditorConstants.lineHeight) -
            editorState.scrollState.verticalOffset +
            (EditorConstants.lineHeight - _textPainter.height) / 2;
        double xPosition = 0;

        _textPainter.paint(canvas, Offset(xPosition, yPosition));
      }
    }

    // Draw carets
    for (var cursor in editorState.cursors) {
      if (cursor.line >= firstVisibleLine && cursor.line < lastVisibleLine) {
        _textPainter.text = TextSpan(
          text: lines[cursor.line].substring(0, cursor.column),
          style: TextStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            color: Colors.black,
          ),
        );
        _textPainter.layout();

        double xPosition = _textPainter.width;
        double yPosition = (cursor.line * EditorConstants.lineHeight) -
            editorState.scrollState.verticalOffset;

        canvas.drawRect(
          Rect.fromLTWH(
            xPosition,
            yPosition,
            2,
            EditorConstants.lineHeight,
          ),
          Paint()..color = Colors.blue,
        );
      }
    }
  }

  @override
  bool shouldRepaint(EditorPainter oldDelegate) {
    return editorState.version != oldDelegate.editorState.version ||
        editorState.scrollState != oldDelegate.editorState.scrollState;
  }
}