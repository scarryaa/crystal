import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/cursor.dart';
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

        double yPosition = (i * EditorConstants.lineHeight) +
            (EditorConstants.lineHeight - _textPainter.height) / 2;
        double xPosition = 0;

        _textPainter.paint(canvas, Offset(xPosition, yPosition));
      }
    }

    // Draw selection
    if (editorState.selection != null) {
      Cursor selection = editorState.selection!;
      Cursor cursor = editorState.cursor;
      Paint selectionPaint = Paint()..color = Colors.blue.withOpacity(0.2);
      int selectionStartLine,
          selectionEndLine,
          selectionStartColumn,
          selectionEndColumn;

      // Normalize selection
      if (selection.line > cursor.line ||
          selection.line == cursor.line && selection.column > cursor.column) {
        selectionStartLine = cursor.line;
        selectionEndLine = selection.line;
        selectionStartColumn = cursor.column;
        selectionEndColumn = selection.column;
      } else {
        selectionStartLine = selection.line;
        selectionEndLine = cursor.line;
        selectionStartColumn = selection.column;
        selectionEndColumn = cursor.column;
      }

      if (selectionStartLine == selectionEndLine) {
        // Single line
        String textUpToSelection = editorState.lines[selectionStartLine]
            .substring(0, selectionStartColumn);
        String textSlice = editorState.lines[selectionStartLine]
            .substring(selectionStartColumn, selectionEndColumn);

        _textPainter.text = TextSpan(
          text: textUpToSelection,
          style: TextStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            color: Colors.black,
          ),
        );
        _textPainter.layout();
        double left = _textPainter.width;

        _textPainter.text = TextSpan(
          text: textSlice,
          style: TextStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            color: Colors.black,
          ),
        );
        _textPainter.layout();
        double width = _textPainter.width;

        canvas.drawRect(
            Rect.fromLTWH(
                left,
                editorState.cursor.line * EditorConstants.lineHeight,
                width,
                EditorConstants.lineHeight),
            Paint()..color = Colors.blue.withOpacity(0.2));
      } else {
        // Multi line selection

        // Start line
        String startLineLeftSlice = editorState.lines[selectionStartLine]
            .substring(0, selectionStartColumn);
        _textPainter.text = TextSpan(
          text: startLineLeftSlice,
          style: TextStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            color: Colors.black,
          ),
        );
        _textPainter.layout();
        double startLineLeft = _textPainter.width;
        double startLineWidth =
            measureLineWidth(editorState.lines[selectionStartLine]) -
                startLineLeft;

        _drawSelectionForLine(canvas, selectionStartLine, startLineLeft,
            startLineWidth, selectionPaint);

        // Middle lines
        for (int i = selectionStartLine + 1; i < selectionEndLine; i++) {
          // Whole line is selected
          double width = measureLineWidth(editorState.lines[i]);
          _drawSelectionForLine(canvas, i, 0, width, selectionPaint);
        }

        // End line
        String endLineSlice = editorState.lines[selectionEndLine]
            .substring(0, selectionEndColumn);
        _textPainter.text = TextSpan(
          text: endLineSlice,
          style: TextStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            color: Colors.black,
          ),
        );
        _textPainter.layout();
        double endLineWidth = _textPainter.width;
        _drawSelectionForLine(
            canvas, selectionEndLine, 0, endLineWidth, selectionPaint);
      }
    }

    // Draw caret
    String textUpToCaret = editorState.lines[editorState.cursor.line]
        .substring(0, editorState.cursor.column);
    _textPainter.text = TextSpan(
      text: textUpToCaret,
      style: TextStyle(
        fontSize: EditorConstants.fontSize,
        fontFamily: EditorConstants.fontFamily,
        color: Colors.black,
      ),
    );
    _textPainter.layout();

    double caretLeft = _textPainter.width;
    double caretTop = EditorConstants.lineHeight * editorState.cursor.line;

    canvas.drawRect(
        Rect.fromLTWH(caretLeft, caretTop, 2.0, EditorConstants.lineHeight),
        Paint()..color = Colors.blue);
  }

  void _drawSelectionForLine(
      Canvas canvas, int lineNumber, double left, double width, Paint paint) {
    canvas.drawRect(
        Rect.fromLTWH(left, lineNumber * EditorConstants.lineHeight, width,
            EditorConstants.lineHeight),
        paint);
  }

  @override
  bool shouldRepaint(EditorPainter oldDelegate) {
    return editorState.version != oldDelegate.editorState.version ||
        editorState.scrollState.horizontalOffset !=
            oldDelegate.editorState.scrollState.horizontalOffset ||
        editorState.scrollState.verticalOffset !=
            oldDelegate.editorState.scrollState.verticalOffset;
  }
}
