import 'dart:math';

import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/editor/painter/painters/background_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/bracket_match_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/caret_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/folding_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/indentation_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/search_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/selection_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/text_painter_helper.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final EditorState editorState;
  final TextPainterHelper textPainterHelper;
  final double viewportHeight;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final String searchTerm;
  final List<SearchMatch> searchTermMatches;
  final int currentSearchTermMatch;
  final BackgroundPainter backgroundPainter;
  final FoldingPainter _foldingPainter;
  final CaretPainter caretPainter;
  final IndentationPainter indentationPainter;
  late final SearchPainter searchPainter;
  late final SelectionPainter selectionPainter;
  final BracketMatchPainter bracketMatchPainter;
  final bool isFocused;
  final Set<int> _currentHighlightedLines = {};

  EditorPainter({
    required this.editorState,
    required this.viewportHeight,
    required this.editorSyntaxHighlighter,
    required this.searchTerm,
    required this.searchTermMatches,
    required this.currentSearchTermMatch,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.isFocused,
  })  : backgroundPainter = BackgroundPainter(
            backgroundColor:
                editorConfigService.themeService.currentTheme != null
                    ? editorConfigService.themeService.currentTheme!.background
                    : Colors.white,
            editorConfigService: editorConfigService,
            editorLayoutService: editorLayoutService),
        selectionPainter = SelectionPainter(
            editorConfigService: editorConfigService,
            editorLayoutService: editorLayoutService,
            editorState),
        searchPainter = SearchPainter(
          editorConfigService: editorConfigService,
          editorLayoutService: editorLayoutService,
          searchTerm: searchTerm,
          searchTermMatches: searchTermMatches,
          currentSearchTermMatch: currentSearchTermMatch,
        ),
        bracketMatchPainter = BracketMatchPainter(
            editorState: editorState,
            cursors: editorState.editorCursorManager.cursors,
            editorLayoutService: editorLayoutService,
            editorConfigService: editorConfigService),
        textPainterHelper = TextPainterHelper(
            editorConfigService: editorConfigService,
            editorLayoutService: editorLayoutService,
            editorSyntaxHighlighter: editorSyntaxHighlighter,
            editorState: editorState),
        caretPainter = CaretPainter(
            editorConfigService: editorConfigService,
            editorLayoutService: editorLayoutService,
            editorState),
        indentationPainter = IndentationPainter(
          editorConfigService: editorConfigService,
          editorLayoutService: editorLayoutService,
          editorState: editorState,
          viewportHeight: viewportHeight,
        ),
        _foldingPainter = FoldingPainter(
          editorLayoutService: editorLayoutService,
          editorConfigService: editorConfigService,
          textPainterHelper: TextPainterHelper(
            editorConfigService: editorConfigService,
            editorLayoutService: editorLayoutService,
            editorSyntaxHighlighter: editorSyntaxHighlighter,
            editorState: editorState,
          ),
          foldedRegions: editorState.foldingState.foldingRanges,
        ),
        super(repaint: editorState);

  @override
  void paint(Canvas canvas, Size size) {
    final scrollOffset = editorState.scrollState.verticalOffset;
    final lineHeight = editorLayoutService.config.lineHeight;
    int firstVisibleLine = max(0, (scrollOffset / lineHeight).floor() - 10);

    // Calculate the maximum line needed for selections
    int maxSelectionLine = firstVisibleLine;
    if (editorState.editorSelectionManager.hasSelection()) {
      for (var selection in editorState.editorSelectionManager.selections) {
        maxSelectionLine =
            max(maxSelectionLine, max(selection.startLine, selection.endLine));
      }
    }

    int lastVisibleLine = firstVisibleLine;
    double accumulatedHeight = 0;
    int visualLines = 0;

    // Extend the visible range to include all selected lines
    while (accumulatedHeight < (viewportHeight + lineHeight * 20) &&
            lastVisibleLine < editorState.buffer.lineCount ||
        lastVisibleLine <= maxSelectionLine) {
      if (!textPainterHelper.isLineHidden(lastVisibleLine)) {
        accumulatedHeight += lineHeight;
        visualLines++;
      }
      lastVisibleLine++;
    }

    // Add buffer but respect content bounds
    lastVisibleLine = min(editorState.buffer.lineCount, lastVisibleLine + 10);

    backgroundPainter.paint(canvas, size);
    textPainterHelper.paintText(canvas, size, firstVisibleLine, lastVisibleLine,
        editorState.buffer.lines);

    _foldingPainter.paint(
      canvas,
      size,
      firstVisibleLine: firstVisibleLine,
      lastVisibleLine: lastVisibleLine,
    );

    // Clear previous highlighted lines
    _currentHighlightedLines.clear();

    // Highlight current line (if no selection)
    if (!editorState.editorSelectionManager.hasSelection()) {
      for (var cursor in editorState.editorCursorManager.cursors) {
        if (!_currentHighlightedLines.contains(cursor.line)) {
          _highlightCurrentLine(canvas, size, cursor.line);
          _currentHighlightedLines.add(cursor.line);
        }
      }
    }

    // Draw search highlights
    searchPainter.paint(canvas, searchTerm, firstVisibleLine, lastVisibleLine);

    // Draw selection
    selectionPainter.paint(canvas, firstVisibleLine, lastVisibleLine);

    bracketMatchPainter.paint(canvas, size,
        firstVisibleLine: firstVisibleLine, lastVisibleLine: lastVisibleLine);

    // Draw caret
    if (editorState.showCaret && isFocused) {
      caretPainter.paint(canvas, size,
          firstVisibleLine: firstVisibleLine, lastVisibleLine: lastVisibleLine);
    }
  }

  void _highlightCurrentLine(Canvas canvas, Size size, int lineNumber) {
    canvas.drawRect(
        Rect.fromLTWH(
          0,
          lineNumber * editorLayoutService.config.lineHeight,
          size.width,
          editorLayoutService.config.lineHeight,
        ),
        Paint()
          ..color = editorConfigService.themeService.currentTheme != null
              ? editorConfigService
                  .themeService.currentTheme!.currentLineHighlight
              : Colors.blue.withOpacity(0.2));
  }

  double measureLineWidth(String line) {
    return textPainterHelper.measureLineWidth(line);
  }

  @override
  bool shouldRepaint(EditorPainter oldDelegate) {
    return editorState.buffer.version !=
            oldDelegate.editorState.buffer.version ||
        editorState.editorSelectionManager.selections !=
            oldDelegate.editorState.editorSelectionManager.selections ||
        editorState.scrollState.horizontalOffset !=
            oldDelegate.editorState.scrollState.horizontalOffset ||
        editorState.scrollState.verticalOffset !=
            oldDelegate.editorState.scrollState.verticalOffset ||
        editorState.showCaret != oldDelegate.editorState.showCaret ||
        isFocused != oldDelegate.isFocused ||
        editorState.cursorShape != oldDelegate.editorState.cursorShape ||
        searchTerm != oldDelegate.searchTerm ||
        currentSearchTermMatch != oldDelegate.currentSearchTermMatch ||
        oldDelegate.editorState.editorCursorManager.cursors !=
            editorState.editorCursorManager.cursors ||
        editorState.foldingState.foldingRanges !=
            oldDelegate.editorState.foldingState.foldingRanges;
  }
}
