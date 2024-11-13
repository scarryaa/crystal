import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class SelectionPainter {
  final EditorState editorState;
  final TextPainter _textPainter;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  SelectionPainter(
    this.editorState, {
    required this.editorLayoutService,
    required this.editorConfigService,
  }) : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        );

  void paint(Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    if (!editorState.editorSelectionManager.hasSelection()) return;

    int visualOffset = 0;

    for (var selection in editorState.editorSelectionManager.selections) {
      final (startLine, endLine, startColumn, endColumn) =
          _normalizeSelection(selection);

      if (endLine < firstVisibleLine || startLine > lastVisibleLine) continue;

      int visualLine = 0;
      for (int i = 0; i < startLine; i++) {
        if (!editorState.foldingState.isLineHidden(i)) {
          visualLine++;
        }
      }
      visualLine -= visualOffset;

      if (startLine == endLine) {
        _paintSingleLineSelection(
            canvas, startLine, startColumn, endColumn, visualLine);
      } else {
        _paintMultiLineSelection(
            canvas,
            startLine,
            endLine,
            startColumn,
            endColumn,
            firstVisibleLine,
            lastVisibleLine,
            visualLine,
            selection);
      }
    }
  }

  (int, int, int, int) _normalizeSelection(var selection) {
    int startLine = selection.startLine;
    int endLine = selection.endLine;
    int startColumn = selection.startColumn;
    int endColumn = selection.endColumn;

    if (startLine > endLine ||
        (startLine == endLine && startColumn > endColumn)) {
      return (endLine, startLine, endColumn, startColumn);
    }
    return (startLine, endLine, startColumn, endColumn);
  }

  void _paintSingleLineSelection(
    Canvas canvas,
    int line,
    int startColumn,
    int endColumn,
    int visualLine,
  ) {
    if (editorState.foldingState.isLineHidden(line)) return;

    _paintSelectionLine(
        canvas,
        line,
        startColumn,
        endColumn,
        visualLine,
        Paint()
          ..color = editorConfigService.themeService.currentTheme?.primary
                  .withOpacity(0.2) ??
              Colors.blue.withOpacity(0.2));
  }

  void _paintMultiLineSelection(
    Canvas canvas,
    int startLine,
    int endLine,
    int startColumn,
    int endColumn,
    int firstVisibleLine,
    int lastVisibleLine,
    int initialVisualLine,
    var originalSelection, // Add this parameter
  ) {
    Paint selectionPaint = Paint()
      ..color = editorConfigService.themeService.currentTheme?.primary
              .withOpacity(0.2) ??
          Colors.blue.withOpacity(0.2);

    int visualLine = initialVisualLine;

    bool startInFold = false;
    int? foldStart;
    int? foldEnd;

    for (final entry in editorState.foldingState.foldingRanges.entries) {
      if (startLine >= entry.key && startLine <= entry.value) {
        startInFold = true;
        foldStart = entry.key;
        foldEnd = entry.value;
        break;
      }
    }

    if (startInFold && foldStart != null) {
      // Check if the selection encompasses the entire fold
      bool entireFoldSelected = originalSelection.startLine < foldStart ||
          (originalSelection.startLine == foldStart &&
              originalSelection.startColumn == 0);

      _paintSelectionLine(
          canvas,
          foldStart,
          entireFoldSelected
              ? 0
              : startColumn, // Use 0 if entire fold is selected
          editorState.buffer.getLineLength(foldStart),
          visualLine,
          selectionPaint);

      if (foldEnd != null) {
        startLine = foldEnd + 1;
      }
    } else {
      if (!editorState.foldingState.isLineHidden(startLine)) {
        _paintSelectionLine(
            canvas, startLine, startColumn, null, visualLine, selectionPaint);
      }
    }

    // Paint middle lines
    for (int line = startLine + 1; line < endLine; line++) {
      if (!editorState.foldingState.isLineHidden(line)) {
        visualLine++;
        _paintSelectionLine(canvas, line, 0, null, visualLine, selectionPaint);
      }
    }

    // Paint end line
    if (!editorState.foldingState.isLineHidden(endLine)) {
      visualLine++;
      _paintSelectionLine(
          canvas, endLine, 0, endColumn, visualLine, selectionPaint);
    }
  }

  void _paintSelectionLine(
    Canvas canvas,
    int line,
    int startColumn,
    int? endColumn,
    int visualLine,
    Paint paint,
  ) {
    String lineText = editorState.buffer.getLine(line);

    // Guard against empty lines
    if (lineText.isEmpty) {
      // Draw minimum width selection for empty lines
      canvas.drawRect(
          Rect.fromLTWH(
              0,
              visualLine * editorLayoutService.config.lineHeight,
              editorConfigService.config.fontSize / 2,
              editorLayoutService.config.lineHeight),
          paint);
      return;
    }

    // Clamp columns to valid range
    startColumn = startColumn.clamp(0, lineText.length);
    endColumn = endColumn?.clamp(0, lineText.length);

    // Calculate start position
    double startX = startColumn > 0
        ? _measureLineWidth(lineText.substring(0, startColumn))
        : 0;

    // Calculate width
    double width;
    if (endColumn != null && startColumn < endColumn) {
      width = _measureLineWidth(lineText.substring(startColumn, endColumn));
    } else {
      width = startColumn < lineText.length
          ? _measureLineWidth(lineText.substring(startColumn))
          : editorConfigService.config.fontSize / 2;
    }

    canvas.drawRect(
        Rect.fromLTWH(
            startX,
            visualLine * editorLayoutService.config.lineHeight,
            width,
            editorLayoutService.config.lineHeight),
        paint);

    _drawWhitespaceIndicators(
        canvas, startColumn, endColumn ?? lineText.length, line, visualLine);
  }

  void _drawWhitespaceIndicators(
    Canvas canvas,
    int startColumn,
    int endColumn,
    int line,
    int visualLine,
  ) {
    final lineText = editorState.buffer.getLine(line);
    for (int i = startColumn; i < endColumn && i < lineText.length; i++) {
      if (lineText[i] == ' ') {
        double x = _measureLineWidth(lineText.substring(0, i)) +
            editorLayoutService.config.charWidth / 2;
        _drawWhitespaceIndicator(
            canvas,
            x,
            visualLine * editorLayoutService.config.lineHeight +
                editorLayoutService.config.lineHeight / 2);
      }
    }
  }

  void _drawWhitespaceIndicator(Canvas canvas, double left, double top) {
    canvas.drawCircle(
        Offset(left,
            top + editorConfigService.config.whitespaceIndicatorRadius / 2),
        editorConfigService.config.whitespaceIndicatorRadius,
        Paint()
          ..color = editorConfigService.themeService.currentTheme != null
              ? editorConfigService
                  .themeService.currentTheme!.whitespaceIndicatorColor
              : Colors.black.withOpacity(0.5));
  }

  double _measureLineWidth(String line) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.width;
  }
}
