import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final EditorState editorState;
  final TextPainter _textPainter;
  final double viewportHeight;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;

  EditorPainter({
    required this.editorState,
    required this.viewportHeight,
    required this.editorSyntaxHighlighter,
  })  : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          strutStyle: StrutStyle(
            fontSize: EditorConstants.fontSize,
            fontFamily: EditorConstants.fontFamily,
            height: 1.0,
            forceStrutHeight: true,
          ),
        ),
        super(repaint: editorState);

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
        ((editorState.scrollState.verticalOffset + viewportHeight) /
                    EditorConstants.lineHeight)
                .ceil() +
            5);
    List<String> lines = editorState.lines;
    lastVisibleLine = lastVisibleLine.clamp(0, lines.length);

    // Draw text
    _drawText(canvas, size, firstVisibleLine, lastVisibleLine, lines);

    // Highlight current line (if no selection)
    if (editorState.selection?.hasSelection != true) {
      _highlightCurrentLine(canvas, size, editorState.cursor.line);
    }

    // Draw selection
    if (editorState.selection != null) {
      _drawSelection(canvas, firstVisibleLine, lastVisibleLine);
    }

    // Draw caret
    _drawCaret(canvas);
  }

  void _drawIndentLines(Canvas canvas, double left, int lineNumber) {
    const double lineOffset = 1;

    canvas.drawLine(
        Offset(left + lineOffset, lineNumber * EditorConstants.lineHeight),
        Offset(
            left + lineOffset,
            lineNumber * EditorConstants.lineHeight +
                EditorConstants.lineHeight),
        EditorConstants.indentLineColor);
  }

  void _highlightCurrentLine(Canvas canvas, Size size, int lineNumber) {
    canvas.drawRect(
        Rect.fromLTWH(
          0,
          lineNumber * EditorConstants.lineHeight,
          size.width,
          EditorConstants.lineHeight,
        ),
        EditorConstants.currentLineHighlight);
  }

  void _drawCaret(Canvas canvas) {
    if (editorState.showCaret) {
      String textUpToCaret = editorState.lines[editorState.cursor.line]
          .substring(0, editorState.cursor.column);
      _textPainter.text = TextSpan(
        text: textUpToCaret,
        style: TextStyle(
          fontSize: EditorConstants.fontSize,
          fontFamily: EditorConstants.fontFamily,
          color: Colors.black,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      );
      _textPainter.layout();

      double caretLeft = _textPainter.width;
      double caretTop = EditorConstants.lineHeight * editorState.cursor.line;

      canvas.drawRect(
          Rect.fromLTWH(caretLeft, caretTop, 2.0, EditorConstants.lineHeight),
          Paint()..color = Colors.blue);
    }
  }

  void _drawWhitespaceIndicatorsForSelectionWhitespace(
      Canvas canvas, int startColumn, int endColumn, int lineNumber) {
    for (int i = startColumn; i < endColumn; i++) {
      if (editorState.lines[lineNumber][i] == ' ') {
        _drawWhitespaceIndicator(
            canvas,
            (i + 0.5) * EditorConstants.charWidth,
            lineNumber * EditorConstants.lineHeight +
                EditorConstants.lineHeight / 2);
      }
    }
  }

  void _drawWhitespaceIndicator(
    Canvas canvas,
    double left,
    double top,
  ) {
    canvas.drawCircle(
      Offset(left, top + EditorConstants.whitespaceIndicatorRadius / 2),
      EditorConstants.whitespaceIndicatorRadius,
      EditorConstants.whitespaceIndicatorColor,
    );
  }

  void _drawSelection(
      Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    Selection selection = editorState.selection!;
    Paint selectionPaint = Paint()..color = Colors.blue.withOpacity(0.2);
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
      // Single line
      if (selectionStartLine >= firstVisibleLine &&
          selectionStartLine <= lastVisibleLine) {
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

        _drawWhitespaceIndicatorsForSelectionWhitespace(
          canvas,
          editorState.selection!.startColumn,
          editorState.selection!.endColumn,
          selectionStartLine,
        );

        canvas.drawRect(
            Rect.fromLTWH(
                left,
                editorState.cursor.line * EditorConstants.lineHeight,
                width,
                EditorConstants.lineHeight),
            Paint()..color = Colors.blue.withOpacity(0.2));
      }
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

      _drawWhitespaceIndicatorsForSelectionWhitespace(
          canvas,
          selectionStartColumn,
          editorState.lines[selectionStartLine].length,
          selectionStartLine);

      _drawSelectionForLine(canvas, selectionStartLine, startLineLeft,
          startLineWidth, selectionPaint);

      // Middle lines
      for (int i = selectionStartLine + 1; i < selectionEndLine; i++) {
        // Check if within visible line bounds
        if (i >= firstVisibleLine && i <= lastVisibleLine) {
          // Whole line is selected
          _drawWhitespaceIndicatorsForSelectionWhitespace(
              canvas, 0, editorState.lines[i].length, i);

          double width = measureLineWidth(editorState.lines[i]);
          _drawSelectionForLine(canvas, i, 0, width, selectionPaint);
        }
      }

      // End line
      String endLineSlice =
          editorState.lines[selectionEndLine].substring(0, selectionEndColumn);
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

      _drawWhitespaceIndicatorsForSelectionWhitespace(
          canvas, 0, selectionEndColumn, selectionEndLine);

      _drawSelectionForLine(
          canvas, selectionEndLine, 0, endLineWidth, selectionPaint);
    }
  }

  void _drawSelectionForLine(
      Canvas canvas, int lineNumber, double left, double width, Paint paint) {
    // Draw small selection for empty lines
    if (width == 0) {
      width = EditorConstants.fontSize / 2;
    }

    canvas.drawRect(
        Rect.fromLTWH(left, lineNumber * EditorConstants.lineHeight, width,
            EditorConstants.lineHeight),
        paint);
  }

  int _countLeadingSpaces(String line) {
    int count = 0;
    for (int j = 0; j < line.length; j++) {
      if (line[j] == ' ') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  void _drawText(Canvas canvas, Size size, int firstVisibleLine,
      int lastVisibleLine, List<String> lines) {
    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (i >= 0 && i < lines.length) {
        // Draw indent lines
        String line = lines[i];
        int leadingSpaces = _countLeadingSpaces(line);

        for (int space = 0; space < leadingSpaces; space += 4) {
          if (line.isNotEmpty && !line.startsWith(' ')) continue;
          double xPosition = space * EditorConstants.charWidth;
          _drawIndentLines(canvas, xPosition, i);
        }

        // Highlight the current line's syntax
        editorSyntaxHighlighter.highlight(line);

        // Create text painter with highlighted spans
        _textPainter.text = editorSyntaxHighlighter.buildTextSpan(line);
        _textPainter.layout();

        double yPosition = (i * EditorConstants.lineHeight) +
            (EditorConstants.lineHeight - _textPainter.height) / 2;

        _textPainter.paint(canvas, Offset(0, yPosition));
      }
    }
  }

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
  bool shouldRepaint(EditorPainter oldDelegate) {
    return editorState.version != oldDelegate.editorState.version ||
        editorState.selection != oldDelegate.editorState.selection ||
        editorState.scrollState.horizontalOffset !=
            oldDelegate.editorState.scrollState.horizontalOffset ||
        editorState.scrollState.verticalOffset !=
            oldDelegate.editorState.scrollState.verticalOffset ||
        editorState.showCaret != oldDelegate.editorState.showCaret;
  }
}
