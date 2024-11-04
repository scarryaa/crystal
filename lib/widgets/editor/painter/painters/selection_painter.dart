import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class SelectionPainter {
  final EditorState editorState;
  final TextPainter _textPainter;

  SelectionPainter(this.editorState)
      : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        );

  void paint(Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    if (editorState.selection == null) return;

    Selection selection = editorState.selection!;
    int selectionStartLine,
        selectionEndLine,
        selectionStartColumn,
        selectionEndColumn;

    // Normalize selection
    if (selection.startLine > selection.endLine ||
        selection.startLine == selection.endLine &&
            selection.startColumn > selection.endColumn) {
      selectionStartLine = selection.endLine;
      selectionEndLine = selection.startLine;
      selectionStartColumn = selection.endColumn;
      selectionEndColumn = selection.startColumn;
    } else {
      selectionStartLine = selection.startLine;
      selectionEndLine = selection.endLine;
      selectionStartColumn = selection.startColumn;
      selectionEndColumn = selection.endColumn;
    }

    if (selectionStartLine == selectionEndLine) {
      _paintSingleLineSelection(
          canvas,
          selectionStartLine,
          selectionStartColumn,
          selectionEndColumn,
          firstVisibleLine,
          lastVisibleLine);
    } else {
      _paintMultiLineSelection(
          canvas,
          selectionStartLine,
          selectionEndLine,
          selectionStartColumn,
          selectionEndColumn,
          firstVisibleLine,
          lastVisibleLine);
    }
  }

  void _paintSingleLineSelection(Canvas canvas, int line, int startColumn,
      int endColumn, int firstVisibleLine, int lastVisibleLine) {
    if (line >= firstVisibleLine && line <= lastVisibleLine) {
      String textUpToSelection =
          editorState.buffer.getLine(line).substring(0, startColumn);
      String textSlice =
          editorState.buffer.getLine(line).substring(startColumn, endColumn);

      _textPainter.text = TextSpan(
        text: textUpToSelection,
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

      _drawWhitespaceIndicators(canvas, startColumn, endColumn, line);

      canvas.drawRect(
          Rect.fromLTWH(
              left,
              editorState.cursor.line * EditorConstants.lineHeight,
              width,
              EditorConstants.lineHeight),
          Paint()..color = Colors.blue.withOpacity(0.2));
    }
  }

  void _paintMultiLineSelection(
      Canvas canvas,
      int startLine,
      int endLine,
      int startColumn,
      int endColumn,
      int firstVisibleLine,
      int lastVisibleLine) {
    Paint selectionPaint = Paint()..color = Colors.blue.withOpacity(0.2);

    // Start line
    String startLineLeftSlice =
        editorState.buffer.getLine(startLine).substring(0, startColumn);
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
        _measureLineWidth(editorState.buffer.getLine(startLine)) -
            startLineLeft;

    _drawWhitespaceIndicators(canvas, startColumn,
        editorState.buffer.getLineLength(startLine), startLine);

    _drawSelectionForLine(
        canvas, startLine, startLineLeft, startLineWidth, selectionPaint);

    // Middle lines
    for (int i = startLine + 1; i < endLine; i++) {
      if (i >= firstVisibleLine && i <= lastVisibleLine) {
        _drawWhitespaceIndicators(
            canvas, 0, editorState.buffer.getLineLength(i), i);

        double width = _measureLineWidth(editorState.buffer.getLine(i));
        _drawSelectionForLine(canvas, i, 0, width, selectionPaint);
      }
    }

    // End line
    String endLineSlice =
        editorState.buffer.getLine(endLine).substring(0, endColumn);
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

    _drawWhitespaceIndicators(canvas, 0, endColumn, endLine);

    _drawSelectionForLine(canvas, endLine, 0, endLineWidth, selectionPaint);
  }

  void _drawSelectionForLine(
      Canvas canvas, int lineNumber, double left, double width, Paint paint) {
    if (width == 0) {
      width = EditorConstants.fontSize / 2;
    }

    canvas.drawRect(
        Rect.fromLTWH(left, lineNumber * EditorConstants.lineHeight, width,
            EditorConstants.lineHeight),
        paint);
  }

  void _drawWhitespaceIndicators(
      Canvas canvas, int startColumn, int endColumn, int lineNumber) {
    for (int i = startColumn; i < endColumn; i++) {
      if (editorState.buffer.getLine(lineNumber)[i] == ' ') {
        _drawWhitespaceIndicator(
            canvas,
            (i + 0.5) * EditorConstants.charWidth,
            lineNumber * EditorConstants.lineHeight +
                EditorConstants.lineHeight / 2);
      }
    }
  }

  void _drawWhitespaceIndicator(Canvas canvas, double left, double top) {
    canvas.drawCircle(
      Offset(left, top + EditorConstants.whitespaceIndicatorRadius / 2),
      EditorConstants.whitespaceIndicatorRadius,
      EditorConstants.whitespaceIndicatorColor,
    );
  }

  double _measureLineWidth(String line) {
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
}
