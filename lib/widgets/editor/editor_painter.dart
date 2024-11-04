import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/editor/painter/painters/background_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/caret_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/indentation_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/search_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/selection_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/text_painter_helper.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final EditorState editorState;
  final TextPainterHelper textPainterHelper;
  final double viewportHeight;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final String searchTerm;
  final List<SearchMatch> searchTermMatches;
  final int currentSearchTermMatch;
  final BackgroundPainter backgroundPainter = const BackgroundPainter();
  final CaretPainter caretPainter;
  final IndentationPainter indentationPainter;
  late final SearchPainter searchPainter;
  late final SelectionPainter selectionPainter;

  EditorPainter({
    required this.editorState,
    required this.viewportHeight,
    required this.editorSyntaxHighlighter,
    required this.searchTerm,
    required this.searchTermMatches,
    required this.currentSearchTermMatch,
  })  : selectionPainter = SelectionPainter(editorState),
        searchPainter = SearchPainter(
          searchTerm: searchTerm,
          searchTermMatches: searchTermMatches,
          currentSearchTermMatch: currentSearchTermMatch,
        ),
        textPainterHelper = TextPainterHelper(
          editorSyntaxHighlighter: editorSyntaxHighlighter,
        ),
        caretPainter = CaretPainter(editorState),
        indentationPainter = IndentationPainter(
          editorState: editorState,
          viewportHeight: viewportHeight,
        ),
        super(repaint: editorState);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    backgroundPainter.paint(canvas, size);

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

    // Draw indentation lines
    indentationPainter.paint(canvas, size,
        firstVisibleLine: firstVisibleLine, lastVisibleLine: lastVisibleLine);

    // Draw text
    textPainterHelper.paintText(
        canvas, size, firstVisibleLine, lastVisibleLine, lines);

    // Highlight current line (if no selection)
    if (editorState.selection?.hasSelection != true) {
      _highlightCurrentLine(canvas, size, editorState.cursor.line);
    }

    // Draw search highlights
    searchPainter.paint(canvas, searchTerm, firstVisibleLine, lastVisibleLine);

    // Draw selection
    selectionPainter.paint(canvas, firstVisibleLine, lastVisibleLine);

    // Draw caret
    caretPainter.paint(canvas, size,
        firstVisibleLine: firstVisibleLine, lastVisibleLine: lastVisibleLine);
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

  static double measureLineWidth(String line) {
    return TextPainterHelper.measureLineWidth(line);
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
