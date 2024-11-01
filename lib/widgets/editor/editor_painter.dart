import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final EditorState editorState;
  final TextPainter _textPainter;
  final double viewportHeight;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final String searchTerm;
  final List<SearchMatch> searchTermMatches;
  final int currentSearchTermMatch;

  EditorPainter({
    required this.editorState,
    required this.viewportHeight,
    required this.editorSyntaxHighlighter,
    required this.searchTerm,
    required this.searchTermMatches,
    required this.currentSearchTermMatch,
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
    _drawBackground(canvas, size);

    // Calculate visible lines
    int firstVisibleLine = max(
        0,
        (editorState.scrollState.verticalOffset / EditorConstants.lineHeight)
                .floor() -
            5);
    int lastVisibleLine = min(
        editorState.buffer.lineCount,
        ((editorState.scrollState.verticalOffset + viewportHeight) /
                    EditorConstants.lineHeight)
                .ceil() +
            5);
    List<String> lines = editorState.buffer.lines;
    lastVisibleLine = lastVisibleLine.clamp(0, lines.length);

    // Draw text
    _drawText(canvas, size, firstVisibleLine, lastVisibleLine, lines);

    // Highlight current line (if no selection)
    if (editorState.selection?.hasSelection != true) {
      _highlightCurrentLine(canvas, size, editorState.cursor.line);
    }

    // Draw search highlights
    if (searchTerm.isNotEmpty) {
      _drawSearchHighlights(
          canvas, searchTerm, firstVisibleLine, lastVisibleLine);
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

  void _drawSearchHighlights(
      Canvas canvas, String searchTerm, int startLine, int endLine) {
    for (int i = 0; i < searchTermMatches.length; i++) {
      if (searchTermMatches[i].lineNumber >= startLine &&
          searchTermMatches[i].lineNumber <= endLine) {
        var left = searchTermMatches[i].startIndex * EditorConstants.charWidth;
        var top = searchTermMatches[i].lineNumber * EditorConstants.lineHeight;
        var width = searchTerm.length * EditorConstants.charWidth;
        var height = EditorConstants.lineHeight;

        canvas.drawRect(
            Rect.fromLTWH(left, top, width, height),
            Paint()
              ..color = i == currentSearchTermMatch
                  ? Colors.blue.withOpacity(0.4)
                  : Colors.blue.withOpacity(0.2));
      }
    }
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

  void _drawBackground(Canvas canvas, Size size) {
    final Paint backgroundPaint = Paint()
      ..color = Colors.white
      ..isAntiAlias = true;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      backgroundPaint,
    );
  }

  void _drawCaret(Canvas canvas) {
    if (editorState.showCaret) {
      String textUpToCaret = editorState.buffer
          .getLine(editorState.cursor.line)
          .substring(0, editorState.cursor.column);
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

      double caretLeft = _textPainter.width;
      double caretTop = EditorConstants.lineHeight * editorState.cursor.line;
      Paint caretPaint = Paint()..color = Colors.blue;

      switch (editorState.cursorShape) {
        case CursorShape.bar:
          canvas.drawRect(
              Rect.fromLTWH(
                  caretLeft, caretTop, 2.0, EditorConstants.lineHeight),
              caretPaint);
          break;
        case CursorShape.block:
          canvas.drawRect(
              Rect.fromLTWH(caretLeft, caretTop, EditorConstants.charWidth,
                  EditorConstants.lineHeight),
              caretPaint);
          break;
        case CursorShape.hollow:
          canvas.drawRect(
              Rect.fromLTWH(caretLeft, caretTop, EditorConstants.charWidth,
                  EditorConstants.lineHeight),
              caretPaint..style = PaintingStyle.stroke);
          break;

        case CursorShape.underline:
          canvas.drawRect(
              Rect.fromLTWH(
                  caretLeft,
                  caretTop + EditorConstants.lineHeight - 2,
                  EditorConstants.charWidth,
                  2),
              caretPaint);
          break;
      }
    }
  }

  void _drawWhitespaceIndicatorsForSelectionWhitespace(
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
        String textUpToSelection = editorState.buffer
            .getLine(selectionStartLine)
            .substring(0, selectionStartColumn);
        String textSlice = editorState.buffer
            .getLine(selectionStartLine)
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
      String startLineLeftSlice = editorState.buffer
          .getLine(selectionStartLine)
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
          measureLineWidth(editorState.buffer.getLine(selectionStartLine)) -
              startLineLeft;

      _drawWhitespaceIndicatorsForSelectionWhitespace(
          canvas,
          selectionStartColumn,
          editorState.buffer.getLineLength(selectionStartLine),
          selectionStartLine);

      _drawSelectionForLine(canvas, selectionStartLine, startLineLeft,
          startLineWidth, selectionPaint);

      // Middle lines
      for (int i = selectionStartLine + 1; i < selectionEndLine; i++) {
        // Check if within visible line bounds
        if (i >= firstVisibleLine && i <= lastVisibleLine) {
          // Whole line is selected
          _drawWhitespaceIndicatorsForSelectionWhitespace(
              canvas, 0, editorState.buffer.getLineLength(i), i);

          double width = measureLineWidth(editorState.buffer.getLine(i));
          _drawSelectionForLine(canvas, i, 0, width, selectionPaint);
        }
      }

      // End line
      String endLineSlice = editorState.buffer
          .getLine(selectionEndLine)
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
    return editorState.buffer.version !=
            oldDelegate.editorState.buffer.version ||
        editorState.selection != oldDelegate.editorState.selection ||
        editorState.scrollState.horizontalOffset !=
            oldDelegate.editorState.scrollState.horizontalOffset ||
        editorState.scrollState.verticalOffset !=
            oldDelegate.editorState.scrollState.verticalOffset ||
        editorState.showCaret != oldDelegate.editorState.showCaret ||
        editorState.cursorShape != oldDelegate.editorState.cursorShape ||
        searchTerm != oldDelegate.searchTerm ||
        currentSearchTermMatch != oldDelegate.currentSearchTermMatch;
  }
}
