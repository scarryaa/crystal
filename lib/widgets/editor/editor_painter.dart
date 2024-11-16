import 'dart:math';

import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/models/git_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/editor/painter/painters/background_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/blame_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/bracket_match_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/caret_painter.dart';
import 'package:crystal/widgets/editor/painter/painters/current_line_highlight_painter.dart';
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
  final CurrentLineHighlightPainter currentLineHighlightPainter;
  late final SearchPainter searchPainter;
  late final SelectionPainter selectionPainter;
  final BracketMatchPainter bracketMatchPainter;
  final bool isFocused;
  final List<BlameLine> blameInfo;
  late final BlamePainter blamePainter;

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
    required this.blameInfo,
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
              editorState: editorState),
          foldedRegions: editorState.foldingRanges,
        ),
        currentLineHighlightPainter = CurrentLineHighlightPainter(
            editorState: editorState,
            editorLayoutService: editorLayoutService,
            editorConfigService: editorConfigService),
        super(repaint: editorState) {
    blamePainter = BlamePainter(
      editorConfigService: editorConfigService,
      editorLayoutService: editorLayoutService,
      blameInfo: blameInfo,
      editorState: editorState,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scrollOffset = editorState.scrollState.verticalOffset;
    final lineHeight = editorLayoutService.config.lineHeight;

    // Calculate visible lines more precisely
    int firstVisibleLine = max(0, (scrollOffset / lineHeight).floor());
    int visibleLineCount =
        (editorState.scrollState.viewportHeight / lineHeight).ceil() + 1;
    int lastVisibleLine =
        min(editorState.buffer.lineCount, firstVisibleLine + visibleLineCount);

    // Add small buffer for partial lines
    int bufferLines = 2;
    lastVisibleLine =
        min(editorState.buffer.lineCount, lastVisibleLine + bufferLines);

    backgroundPainter.paint(canvas, size);

    indentationPainter.paint(
      canvas,
      size,
      firstVisibleLine: firstVisibleLine,
      lastVisibleLine: lastVisibleLine,
    );

    textPainterHelper.paintText(canvas, size, firstVisibleLine, lastVisibleLine,
        editorState.buffer.lines);

    _foldingPainter.paint(
      canvas,
      size,
      firstVisibleLine: firstVisibleLine,
      lastVisibleLine: lastVisibleLine,
    );

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

    // Highlight current line
    currentLineHighlightPainter.paint(canvas, size,
        firstVisibleLine: firstVisibleLine, lastVisibleLine: lastVisibleLine);
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
        editorState.foldingRanges != oldDelegate.editorState.foldingRanges ||
        oldDelegate.blameInfo != blameInfo;
  }
}
