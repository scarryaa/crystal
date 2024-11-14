import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class SelectionPainter {
  final EditorState editorState;
  final TextPainter _textPainter;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  // Reuse the same TextStyle
  late final TextStyle _measureStyle;

  SelectionPainter(
    this.editorState, {
    required this.editorLayoutService,
    required this.editorConfigService,
  }) : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        ) {
    _measureStyle = TextStyle(
      fontFamily: editorConfigService.config.fontFamily,
      fontSize: editorConfigService.config.fontSize,
      fontWeight: FontWeight.normal,
    );
    _textPainter.text = TextSpan(style: _measureStyle);
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

    if (lineText.isEmpty) {
      canvas.drawRect(
          Rect.fromLTWH(
              0,
              visualLine * editorLayoutService.config.lineHeight,
              editorConfigService.config.fontSize / 2,
              editorLayoutService.config.lineHeight),
          paint);
      return;
    }

    startColumn = startColumn.clamp(0, lineText.length);
    endColumn = endColumn?.clamp(0, lineText.length);

    // Calculate positions more efficiently
    double startX = 0;
    if (startColumn > 0) {
      startX = startColumn * editorLayoutService.config.charWidth;
    }

    double width;
    if (endColumn != null && startColumn < endColumn) {
      width = (endColumn - startColumn) * editorLayoutService.config.charWidth;
    } else {
      width = (lineText.length - startColumn) *
          editorLayoutService.config.charWidth;
    }

    // Batch draw operations
    canvas.drawRect(
        Rect.fromLTWH(
            startX,
            visualLine * editorLayoutService.config.lineHeight,
            width,
            editorLayoutService.config.lineHeight),
        paint);

    // Only draw whitespace indicators if configured
    _drawWhitespaceIndicators(
        canvas, startColumn, endColumn ?? lineText.length, line, visualLine);
  }

  (int, int, int, int) _normalizeSelection(var selection) {
    int startLine = selection.startLine;
    int endLine = selection.endLine;

    // Add a bounds check here
    endLine = endLine.clamp(0, editorState.buffer.lineCount - 1);

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
    if (editorState.isLineHidden(line)) return;

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
    var originalSelection,
  ) {
    // Validate line bounds
    endLine = endLine.clamp(0, editorState.buffer.lineCount - 1);
    startLine = startLine.clamp(0, editorState.buffer.lineCount - 1);

    Paint selectionPaint = Paint()
      ..color = editorConfigService.themeService.currentTheme?.primary
              .withOpacity(0.2) ??
          Colors.blue.withOpacity(0.2);

    int visualLine = initialVisualLine;

    // Handle start line
    if (!editorState.isLineHidden(startLine)) {
      _paintSelectionLine(
          canvas, startLine, startColumn, null, visualLine, selectionPaint);
    }

    // Paint middle lines
    for (int line = startLine + 1; line < endLine; line++) {
      if (line >= editorState.buffer.lineCount) break;

      if (!editorState.isLineHidden(line)) {
        visualLine++;
        _paintSelectionLine(canvas, line, 0, null, visualLine, selectionPaint);
      }
    }

    // Paint end line if within bounds
    if (endLine < editorState.buffer.lineCount &&
        !editorState.isLineHidden(endLine)) {
      visualLine++;
      _paintSelectionLine(
          canvas, endLine, 0, endColumn, visualLine, selectionPaint);
    }
  }

  void _drawWhitespaceIndicators(
    Canvas canvas,
    int startColumn,
    int endColumn,
    int line,
    int visualLine,
  ) {
    final lineText = editorState.buffer.getLine(line);

    // Pre-calculate the base width once
    double baseWidth = editorLayoutService.config.charWidth;

    for (int i = startColumn; i < endColumn && i < lineText.length; i++) {
      if (lineText[i] == ' ') {
        double x = i * baseWidth + baseWidth / 2;
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

  void paint(Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    if (!editorState.editorSelectionManager.hasSelection()) return;

    // Pre-calculate visual lines
    final visualLines = _calculateVisualLines(firstVisibleLine);

    for (var selection in editorState.editorSelectionManager.selections) {
      final (startLine, endLine, startColumn, endColumn) =
          _normalizeSelection(selection);

      if (endLine < firstVisibleLine || startLine > lastVisibleLine) continue;

      if (startLine == endLine) {
        final visualLine = visualLines[startLine];
        if (visualLine != null) {
          _paintSingleLineSelection(
              canvas, startLine, startColumn, endColumn, visualLine);
        }
      } else {
        // Get the visual line for the start line
        final initialVisualLine = visualLines[startLine] ?? 0;

        _paintMultiLineSelection(
            canvas,
            startLine,
            endLine,
            startColumn,
            endColumn,
            firstVisibleLine,
            lastVisibleLine,
            initialVisualLine,
            selection);
      }
    }
  }

  Map<int, int> _calculateVisualLines(int firstVisibleLine) {
    final Map<int, int> visualLines = {};
    int visualLine = 0;

    for (int i = 0; i < firstVisibleLine; i++) {
      if (!editorState.isLineHidden(i)) {
        visualLine++;
      }
    }

    for (int i = firstVisibleLine; i < editorState.buffer.lineCount; i++) {
      if (!editorState.isLineHidden(i)) {
        visualLines[i] = visualLine++;
      }
    }

    return visualLines;
  }
}
